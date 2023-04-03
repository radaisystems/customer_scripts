-- FC-384995 query to extract job data including CDA (XML) based on FC-361805 for RadAI.
-- This version will extract the report from the PCDS if the infoset in the job table is null.
-- Create one file per week until complete.
-- Modified 8/10/21 by jkelton to use dictating_author_guid instead of signing_author_guid. Why?
--          2/07/22 by jkelton changed back to signing_author_guid for provider
--                             added contributor1 and contributor2 values in the output
--          2/14/22 by jkelton Contributor values were incorrect in the reports.
--       3/08/22 by jkelton Added JobCreatedDateTimeUTC
/*

Required Data:
   Patient Age (Years or DOB)
   Report Signed Date/Time
   Interpreter First Name
   Interpreter Last Name
   Interpreter Code (RIS ID)
   Modality
   Report Text (Split each section into a separate field if possible)
   Exam Name

Preferred Data:
   Observation Date/Time
   Body part
   Patient Type (Inpatient, Outpatient, ER, etc)
   Report Begin Date/Time
   Study Complete Date/Time

Author: John Kelton
Date: 7/29/2021

***** 2/4/2022: Additional fields needed to support contributors and addendums *****

<ContributorId1>
<ContributorFirstName1>
<ContributorLastName1>
 
And
 
<ContributorId2>
<ContributorFirstName2>
<ContributorLastName2>
 
You can only have one signing author per report. But you can have multiple signing authors per accession (original + addendum). I will include a flag for addendum:
 
<Addendum> (0=not an addendum, 1=addendum)

*/

/*************************** IMPORTANT ***********************************
 Be sure to set the query options as follows:
    1. Uncheck 'include column headers'
    2. Set the 'maximum number of characters displayed' to 8192
    3. Set the SSMS to output 'Results to grid'
*********************************************************************************
 If you receive an error while attempting to create the file system object, 
   (Msg 15281, Level 16, State 1, Procedure sp_OACreate)
   execute the following script to enable Ole Automation which is required to
   allow SQL Server to access the file system.

   sp_configure 'show advanced options', 1;
   GO
   RECONFIGURE;
   GO
   sp_configure 'Ole Automation Procedures', 1;
   GO
   RECONFIGURE;
   SELECT * FROM sys.configurations

* ********************************************************************************/

-- Specify the path to export the data to:
DECLARE @Path VARCHAR(MAX) = 'D:\ReportExport'

-- Specify Begin and End dates in UTC (dates inclusive, default time is 12:00am)
Declare  @BeginDate datetime = '7/1/2019 05:00',
      @EndDate datetime = '6/30/2022 04:59'


/*******************************
 Do not modify below this line
*******************************/

SET QUOTED_IDENTIFIER ON
SET nocount ON
Use MModalServices
--------------------------------------------------------
DECLARE @Filename VARCHAR(50)='FFI_Reports'
DECLARE @String nvarchar(MAX)=''
DECLARE @Report nvarchar(MAX)=''
--------------------------------------------------------
DECLARE @objFileSystem int
DECLARE @objTextStream int
DECLARE  @objErrorObject int
DECLARE @strErrorMessage Varchar(MAX)
DECLARE @Command varchar(MAX)
DECLARE @hr int
DECLARE  @fileAndPath varchar(MAX)
--------------------------------------------------------
DECLARE @chkdirectory as nvarchar(4000)
DECLARE @folder_exists as int
--------------------------------------------------------
DECLARE @Source VARCHAR(MAX)
DECLARE  @Description VARCHAR(MAX)
DECLARE  @Helpfile VARCHAR(MAX)
DECLARE  @HelpID INT
--------------------------------------------------------
Declare @chars nvarchar(max) = ''
Declare @sectioncnt int
Declare @subsectioncnt int
Declare @paragraphcnt int
Declare @listitemcnt int
Declare @contentcnt int
Declare @l int = 1
Declare @s int = 1
Declare @ss int = 1
Declare @p int = 1
Declare @c int = 1
Declare @charcnt int
Declare @job_id int,
      @accession nvarchar(50),
      @Patient_DOB datetime2(2),
      @sPatient_DOB nvarchar(10),
      @CreatedDate datetime,
      @sCreatedDate nvarchar(19),
      @SignedDate datetime2(4),
      @sSignedDate nvarchar(19),
      @ProvFirstName nvarchar(50),
      @ProvLastName nvarchar(50),
      @ProvID nvarchar(50),
      @sign_author_guid uniqueidentifier,
      @ContributorId nvarchar(50),
      @ContributorFirstName nvarchar(50),
      @ContributorLastName nvarchar(50),
      @ContributorId1 nvarchar(50),
      @ContributorFirstName1 nvarchar(50),
      @ContributorLastName1 nvarchar(50),
      @ContributorId2 nvarchar(50),
      @ContributorFirstName2 nvarchar(50),
      @ContributorLastName2 nvarchar(50),
      @Modality varchar(50),
      @ProcDesc nvarchar(255),
      @Addendum bit, -- 0=not an addendum, 1=addendum
      @cda xml,
      @pcdsDocument bit,
      @issuer uniqueidentifier
Declare @z table (job_id int,accession nvarchar(50),Patient_DOB datetime2(2),CreatedDate datetime,SignedDate datetime2(4),ProvFirstName nvarchar(50),ProvLastName nvarchar(50),ProvID nvarchar(50),ContributorId1 nvarchar(50),ContributorFirstName1 nvarchar(50),ContributorLastName1 nvarchar(50),ContributorId2 nvarchar(50),ContributorFirstName2 nvarchar(50),ContributorLastName2 nvarchar(50),Modality varchar(50),ProcDesc nvarchar(255),Addendum bit,Report nvarchar(max),PCDSDocumentFlag bit)

IF @Path = ''
BEGIN
   PRINT 'Path must be specified.'
   PRINT 'Please modify the value for the @Path paramater and try again.'
   RETURN
END

DECLARE @file_results table
(
   file_exists int,
   file_is_a_directory int,
    parent_directory_exists int
)

Select 'Searching for jobs between ' + convert(nvarchar(12),@begindate) + ' and ' + convert(nvarchar(12),@enddate)
While @begindate<@enddate
Begin
   --Select 'Getting reports for week: ' + convert(nvarchar(12),@begindate) --Can be very CPU intensive. Only use for short date ranges
   Set @String = '<FFIDocuments>'
   Declare c1 cursor for 
      select   job_id,
            accession_number,
            patient_birth_date,
            job_created_time_utc,
            job_updated_time_utc,
            p.GivenName,
            p.FamilyName,
            pro.ProviderIdentifier,
            vjpe.signing_author_guid,
            Modality,
            procedure_description,
            vjpe.is_addendum,
            (case when infoset is NULL then convert(xml,d.ContentXml) else infoset end),
            (case when infoset is NULL then 1 else 0 end),
            ExamIssuerKey
      FROM [MModalServices].[dbo].[View_JobPatientExams] (nolock) vjpe
      INNER JOIN [MModalServices].[dbo].[Job] on id=job_id
      INNER JOIN [ClinicalDataStore].[User].[User] u on u.userkey=vjpe.signing_author_guid
      INNER JOIN [ClinicalDataStore].[Person].[Person] p ON p.[BusinessEntityId] = u.BusinessEntityId
      INNER JOIN [ClinicalDataStore].[Clinical].[Provider_User] pu on pu.UserId=u.BusinessEntityId
       JOIN [ClinicalDataStore].[Clinical].[Provider] pro on pro.BusinessEntityId=pu.ProviderId and vjpe.ExamIssuerKey=pro.IssuerKey
      left JOIN [ClinicalDataStore].[Clinical].[Document] d on d.DocumentIdentifier=vjpe.accession_number and d.IssuerKey=vjpe.ExamIssuerKey
      where main_exam_flag=1
         and vjpe.job_state='signed'
         and job_created_time_utc between @BeginDate and DATEADD(WEEK,1,dateadd(SS,-1,@begindate))
      order by job_id
   open c1
   Fetch next from c1 into @job_id,
                     @accession,
                     @Patient_DOB,
                     @CreatedDate,
                     @SignedDate,
                     @ProvFirstName,
                     @ProvLastName,
                     @ProvID,
                     @sign_author_guid,
                     @Modality,
                     @ProcDesc,
                     @addendum,
                     @cda,
                     @pcdsDocument,
                     @issuer
   while @@FETCH_STATUS=0
   BEGIN
   If @pcdsDocument=0
   Begin
      --Get the Section Count
      select @sectioncnt=@cda.value('declare namespace ns="urn:hl7-org:v3"; count(//ns:structuredBody/ns:component/ns:section)','int')
      --select @sectioncnt --Debug
      if @sectioncnt!=0
      BEGIN
         While @s<=@sectioncnt
         Begin
            --Get the Title
            select @chars=@chars+(select XTbl.XNodes.value('declare namespace ns="urn:hl7-org:v3"; (ns:title)[1]','nvarchar(30)')
            FROM @cda.nodes('declare namespace ns="urn:hl7-org:v3"; //ns:structuredBody/ns:component[sql:variable("@s")]/ns:section') AS XTbl(XNodes))+char(13)
            --Check for LIST items
            select @listitemcnt=@cda.value('declare namespace ns="urn:hl7-org:v3"; count(//ns:structuredBody/ns:component[sql:variable("@s")]/ns:section/ns:text/ns:list/ns:item)','int')
            if @listitemcnt!=0 (Select @chars=@chars)
            While @l<=@listitemcnt
            BEGIN
               --Get the List Paragraph count
               select @paragraphcnt=@cda.value('declare namespace ns="urn:hl7-org:v3"; count(//ns:structuredBody/ns:component[sql:variable("@s")]/ns:section/ns:text/ns:list/ns:item[sql:variable("@l")]/ns:paragraph)','int')
               If @paragraphcnt=0 (select @chars=@chars+' ')
               else
               While @p<=@paragraphcnt
               --Get all child nodes
               Begin
                  Select @chars=@chars+convert(nvarchar(3),@l)+'. '
                  Select @chars=@chars+XTbl.XNodes.value('declare namespace ns="urn:hl7-org:v3"; (.)[1]','varchar(max)')
                  FROM @cda.nodes('declare namespace ns="urn:hl7-org:v3"; //ns:structuredBody/ns:component[sql:variable("@s")]/ns:section/ns:text/ns:list/ns:item[sql:variable("@l")]/ns:paragraph[sql:variable("@p")]/ns:content') AS XTbl(XNodes)
                  Select @chars=@chars+char(13)
                  set @p=@p+1
               End
               Select @chars=@chars+char(13)
               set @p=1
               set @l=@l+1
            End
            --Select @chars --Debug
            set @l=1
            --Get the Paragraph count
            select @paragraphcnt=@cda.value('declare namespace ns="urn:hl7-org:v3"; count(//ns:structuredBody/ns:component[sql:variable("@s")]/ns:section/ns:text/ns:paragraph)','int')
            --select @paragraphcnt --Debug
            If @paragraphcnt=0 (select @chars=@chars+' ')
            else
            While @p<=@paragraphcnt
            --Get all child nodes
            Begin
               Select @chars=@chars+XTbl.XNodes.value('declare namespace ns="urn:hl7-org:v3"; (.)[1]','varchar(max)')
               FROM @cda.nodes('declare namespace ns="urn:hl7-org:v3"; //ns:structuredBody/ns:component[sql:variable("@s")]/ns:section/ns:text/ns:paragraph[sql:variable("@p")]/ns:content') AS XTbl(XNodes)
               Select @chars=@chars+char(13)
               set @p=@p+1
            End
            set @p=1
            --Check for subsections
            select @subsectioncnt=@cda.value('declare namespace ns="urn:hl7-org:v3"; count(//ns:structuredBody/ns:component[sql:variable("@s")]/ns:component/ns:section)','int')
            While @ss<=@subsectioncnt
            Begin
               --Get the Subsection Title
               select @chars=@chars+'<h4>'+(select XTbl.XNodes.value('declare namespace ns="urn:hl7-org:v3"; (ns:title)[1]','nvarchar(30)')
               FROM @cda.nodes('declare namespace ns="urn:hl7-org:v3"; //ns:structuredBody/ns:component[sql:variable("@s")]/ns:component[sql:variable("@ss")]/ns:section') AS XTbl(XNodes))+'</h4>'
               --Get the Subsection Paragraph count
               select @paragraphcnt=(select XTbl.XNodes.value('declare namespace ns="urn:hl7-org:v3"; count(ns:text/ns:paragraph)','int')
                  from @cda.nodes('declare namespace ns="urn:hl7-org:v3"; //ns:structuredBody/ns:component[sql:variable("@s")]/ns:component[sql:variable("@ss")]/ns:section') as XTbl(XNodes))
               If @paragraphcnt=0 (select @chars=@chars+' ') 
               While @p<=@paragraphcnt
               --Get all child nodes in Subsection Paragraph
               Begin
                  Select @chars=@chars+char(13)
                  Select @chars=@chars+XTbl.XNodes.value('declare namespace ns="urn:hl7-org:v3"; (.)[1]','varchar(max)')
                     FROM @cda.nodes('declare namespace ns="urn:hl7-org:v3"; //ns:structuredBody/ns:component[sql:variable("@s")]/ns:component[sql:variable("@ss")]/ns:section/ns:text/ns:paragraph[sql:variable("@p")]/ns:content') AS XTbl(XNodes)
                  set @p=@p+1
               End
               Select @chars=@chars
               set @p=1
               set @ss=@ss+1
            End
         set @chars=@chars+char(13)
         set @s=@s+1
         End
      End
      --Get the Paragraph count (no sections)
      set @p=1
      select @paragraphcnt=@cda.value('declare namespace ns="urn:hl7-org:v3"; count(/ns:normal/ns:text/ns:paragraph)','int')
      If @paragraphcnt!=0
      Begin
         --If @paragraphcnt=0 (select @chars=@chars+'&nbsp;')
         While @p<=@paragraphcnt
         --Get all child nodes
         Begin
            Select @chars=@chars+char(13)
            Select @chars=@chars+XTbl.XNodes.value('declare namespace ns="urn:hl7-org:v3"; (.)[1]','varchar(max)')
            FROM @cda.nodes('declare namespace ns="urn:hl7-org:v3"; /ns:normal/ns:text/ns:paragraph[sql:variable("@p")]/ns:content') AS XTbl(XNodes)
            set @p=@p+1
         End
         Select @chars=@chars
         set @p=1
      End
      --Get Content (no sections nor paragraphs)
      select @contentcnt=@cda.value('declare namespace ns="urn:hl7-org:v3"; count(/ns:normal/ns:content)','int')
      if @contentcnt!=0
      BEGIN
         Select @chars=@chars+XTbl.XNodes.value('declare namespace ns="urn:hl7-org:v3"; (.)[1]','varchar(max)')
         FROM @cda.nodes('declare namespace ns="urn:hl7-org:v3"; /ns:normal/ns:content') AS XTbl(XNodes)
      End
   End
   If @pcdsDocument=1
   BEGIN
      --Get the Paragraph count
      set @p=1
      select @paragraphcnt=@cda.value('count(/Document/Observation/Segment)','int')
      If @paragraphcnt!=0
      Begin
         --If @paragraphcnt=0 (select @chars=@chars+'&nbsp;')
         While @p<=@paragraphcnt
         --Get all child nodes
         Begin
            Select @chars=@chars+char(13)
            Select @chars=@chars+XTbl.XNodes.value('(.)[1]','varchar(max)')
            FROM @cda.nodes('/Document/Observation/Segment[sql:variable("@p")]') AS XTbl(XNodes)
            set @p=@p+1
         End
         --Select @chars=@chars
         set @p=1
      End
   End

   -- Get the contributing authors
   Set @ContributorFirstName1=NULL
   Set @ContributorLastName1=NULL
   Set @ContributorId1=NULL
   Set @ContributorFirstName2=NULL
   Set @ContributorLastName2=NULL
   Set @ContributorId2=NULL
   Declare c3 cursor for
      Select distinct p.GivenName,p.FamilyName,pro.ProviderIdentifier
      From job_history jh
      Join [ClinicalDataStore].[User].[User] u on u.UserKey=jh.action_by_guid
      join ClinicalDataStore.Clinical.BusinessEntity be on be.BusinessEntityId=u.BusinessEntityId
      join [ClinicalDataStore].[Person].[Person] p on p.BusinessEntityId=be.BusinessEntityId
      JOIN [ClinicalDataStore].[Clinical].[Provider_User] pu on pu.UserId=u.BusinessEntityId
      JOIN [ClinicalDataStore].[Clinical].[Provider] pro on pro.BusinessEntityId=pu.ProviderId
      join [ClinicalDataStore].[User].[User_Group] ug on ug.UserId=u.BusinessEntityId
      join [ClinicalDataStore].[User].[Group] g on g.BusinessEntityId=ug.GroupId
      Where jh.job_id=@job_id
           and jh.name='launch'
           and g.Name not like '%transcription%'
           and jh.action_by_guid!=@sign_author_guid
           and pro.IssuerKey=@issuer
   Open c3
   Fetch next from c3 into @ContributorFirstName,@ContributorLastName,@ContributorId
   While @@FETCH_STATUS=0
   BEGIN
      --Select @job_id,@c,@ContributorFirstName,@ContributorLastName,@ContributorId
      If @c=1
      Begin
         Set @ContributorFirstName1=@ContributorFirstName
         Set @ContributorLastName1=@ContributorLastName
         Set @ContributorId1=@ContributorId
         --Select @job_id,@c,@ContributorFirstName1,@ContributorLastName1,@ContributorId1
      End
      If @c=2
      Begin
         Set @ContributorFirstName2=@ContributorFirstName
         Set @ContributorLastName2=@ContributorLastName
         Set @ContributorId2=@ContributorId
         --Select @job_id,@c,@ContributorFirstName2,@ContributorLastName2,@ContributorId2
      End
      Set @c=@c+1
      Fetch next from c3 into @ContributorFirstName1,@ContributorLastName1,@ContributorId1
   End
   Close c3
   Deallocate c3
   Set @c=1
      insert into @z 
            select  @job_id,
                  @accession,
                  @Patient_DOB,
                  @CreatedDate,
                  @SignedDate,
                  @ProvFirstName,
                  @ProvLastName,
                  @ProvID,
                  @ContributorFirstName1,
                  @ContributorLastName1,
                  @ContributorId1,
                  @ContributorFirstName2,
                  @ContributorLastName2,
                  @ContributorId2,
                  @Modality,
                  @ProcDesc,
                  @addendum,
                  @chars,
                  @pcdsDocument
      --Reset variables
      Set @l = 1
      Set @s = 1
      Set @ss = 1
      Set @p = 1
      Set @chars = ''
      Fetch next from c1 into @job_id,
                        @accession,
                        @Patient_DOB,
                        @CreatedDate,
                        @SignedDate,
                        @ProvFirstName,
                        @ProvLastName,
                        @ProvID,
                        @sign_author_guid,
                        @Modality,
                        @ProcDesc,
                        @addendum,
                        @cda,
                        @pcdsDocument,
                        @issuer
   End
   --Select * from @z
   close c1
   deallocate c1

   -- Write out the data to an XML file

   Declare c2 cursor for
      Select   job_id,
            accession,
            Patient_DOB,
            CreatedDate,
            SignedDate,
            ProvFirstName,
            ProvLastName,
            ProvID,
            ContributorFirstName1,
            ContributorLastName1,
            ContributorId1,
            ContributorFirstName2,
            ContributorLastName2,
            ContributorId2,
            Modality,
            ProcDesc,
            Addendum,
            Report
      From @z

   open c2
   Fetch next from c2 into @job_id,
                     @accession,
                     @Patient_DOB,
                     @CreatedDate,
                     @SignedDate,
                     @ProvFirstName,
                     @ProvLastName,
                     @ProvID,
                     @ContributorFirstName1,
                     @ContributorLastName1,
                     @ContributorId1,
                     @ContributorFirstName2,
                     @ContributorLastName2,
                     @ContributorId2,
                     @Modality,
                     @ProcDesc,
                     @addendum,
                     @Report
   while @@FETCH_STATUS=0
   BEGIN
      -- Convert the dates into a good format
      set @sPatient_DOB=convert(varchar,@Patient_DOB, 120)
      set @sSignedDate=convert(varchar,@SignedDate,120)
      set @sCreatedDate=convert(varchar,@CreatedDate,120)
      --select @Patient_DOB,@SignedDate,@sPatient_DOB,@sSignedDate

      -- Create the XML
      SET @chars =   '<FFIReport>'+
                  '<job_id>'+ISNULL(convert(varchar(10),@job_id),'')+'</job_id>'+
                  '<accession>'+isnull(@accession,'')+'</accession>'+
                  '<Patient_DOB>'+isnull(@sPatient_DOB,'')+'</Patient_DOB>'+
                  '<CreatedDate>'+isnull(@sCreatedDate,'')+'</CreatedDate>'+
                  '<SignedDate>'+isnull(@sSignedDate,'')+'</SignedDate>'+
                  '<ProvFirstName>'+isnull(@ProvFirstName,'')+'</ProvFirstName>'+
                  '<ProvLastName>'+isnull(@ProvLastName,'')+'</ProvLastName>'+
                  '<ProvID>'+isnull(@ProvID,'')+'</ProvID>'+
                  '<ContributorFirstName1>'+isnull(@ContributorFirstName1,'')+'</ContributorFirstName1>'+
                  '<ContributorLastName1>'+isnull(@ContributorLastName1,'')+'</ContributorLastName1>'+
                  '<ContributorId1>'+isnull(@ContributorId1,'')+'</ContributorId1>'+
                  '<ContributorFirstName2>'+isnull(@ContributorFirstName2,'')+'</ContributorFirstName2>'+
                  '<ContributorLastName2>'+isnull(@ContributorLastName2,'')+'</ContributorLastName2>'+
                  '<ContributorId2>'+isnull(@ContributorId2,'')+'</ContributorId2>'+
                  '<Modality>'+isnull(@Modality,'')+'</Modality>'+
                  '<ProcDesc>'+isnull(@ProcDesc,'')+'</ProcDesc>'+
                  '<Addendum>'+ISNULL(convert(varchar(1),@Addendum),'')+'</Addendum>'+
                  '<Report>'+isnull(@Report,'')+'</Report>'+
                  '</FFIReport>'
      --Select @chars
      Select @String=@String+@chars
      --Select @String
   Fetch next from c2 into @job_id,
                     @accession,
                     @Patient_DOB,
                     @CreatedDate,
                     @SignedDate,
                     @ProvFirstName,
                     @ProvLastName,
                     @ProvID,
                     @ContributorFirstName1,
                     @ContributorLastName1,
                     @ContributorId1,
                     @ContributorFirstName2,
                     @ContributorLastName2,
                     @ContributorId2,
                     @Modality,
                     @ProcDesc,
                     @addendum,
                     @Report
   End
   close c2
   deallocate c2
   Set nocount off
   Select @String=@String+'</FFIDocuments>'

   /****************************
      FILE WRITER ROUTINES
   ****************************/
   -- Begin Write to file routines
   SELECT @strErrorMessage='Opening the File System Object'
   EXECUTE @hr = sp_OACreate  'Scripting.FileSystemObject' , @objFileSystem OUT

   -- Begin folder management routine
   BEGIN
   -- Check to see if folder already exists

   -- Check to see if root path exists
   SET @chkdirectory = @path
 
   INSERT INTO 
      @file_results 
      (
         file_exists, 
         file_is_a_directory, 
         parent_directory_exists
      )

   EXEC MASTER.dbo.xp_fileexist @chkdirectory
     
   SELECT
      @folder_exists = file_is_a_directory
   FROM
      @file_results

   -- Create folder if if does not exist     
   IF @folder_exists = 0
   BEGIN
      EXECUTE master.dbo.xp_create_subdir @chkdirectory
   END       

   DELETE FROM @file_results

   SET @chkdirectory = @path

   INSERT INTO 
      @file_results 
      (
         file_exists, 
         file_is_a_directory, 
         parent_directory_exists
      )

   EXEC MASTER.dbo.xp_fileexist @chkdirectory
     
   SELECT
      @folder_exists = file_is_a_directory
   FROM
      @file_results

   -- Create folder if if does not exist     
   IF @folder_exists = 0
   BEGIN
      EXECUTE master.dbo.xp_create_subdir @chkdirectory
   END       

   END
   /* End folder management routine */

   /* Begin file write routine */
   BEGIN

   SELECT @FileAndPath=@path+'\'+ @filename + Convert(varchar(10),@BeginDate,23) + '.xml'

   --Select @string

   IF @HR=0 SELECT @objErrorObject=@objFileSystem , @strErrorMessage='Creating file "'+@FileAndPath+'"'
   IF @HR=0 EXECUTE @HR = sp_OAMethod   @objFileSystem   , 'CreateTextFile', @objTextStream OUT, @FileAndPath,2,True

   IF @HR=0 SELECT @objErrorObject=@objTextStream, @strErrorMessage='writing to the file "'+@FileAndPath+'"'
   IF @HR=0 EXECUTE @HR = sp_OAMethod  @objTextStream, 'Write', Null, @String

   IF @HR=0 SELECT @objErrorObject=@objTextStream, @strErrorMessage='closing the file "'+@FileAndPath+'"'
   IF @HR=0 EXECUTE @HR = sp_OAMethod  @objTextStream, 'Close'

   IF @HR<>0
      BEGIN
   
      EXECUTE sp_OAGetErrorInfo  @objErrorObject, 
         @source output,@Description output,@Helpfile output,@HelpID output
      SELECT @strErrorMessage='Error whilst '
            +coalesce(@strErrorMessage,'doing something')
            +', '+coalesce(@Description,'')
      RAISERROR (@strErrorMessage,16,1)
      END
   
   EXECUTE sp_OADestroy @objTextStream
   EXECUTE sp_OADestroy @objFileSystem
   END
   /* End file write routine */
--Reset variables
Select @String=''
Select @chars=''
delete from @z
Set @begindate=DATEADD(WEEK, 1, @begindate)
End
