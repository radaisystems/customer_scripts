DECLARE @Path VARCHAR(MAX) = 'D:\ReportExport'
DECLARE @BeginDate datetime = '7/1/2019 05:00'
DECLARE @EndDate datetime = '6/30/2022 04:59'
SET QUOTED_IDENTIFIER ON
SET nocount ON
Use MModalServices

DECLARE @Filename VARCHAR(50) = 'FFI_Reports'
DECLARE @String nvarchar(MAX) = ''
DECLARE @Report nvarchar(MAX) = ''
DECLARE @objFileSystem int
DECLARE @objTextStream int
DECLARE @objErrorObject int
DECLARE @strErrorMessage Varchar(MAX)
DECLARE @Command varchar(MAX)
DECLARE @hr int
DECLARE @fileAndPath varchar(MAX)
DECLARE @chkdirectory as nvarchar(4000)
DECLARE @folder_exists as int
DECLARE @Source VARCHAR(MAX)
DECLARE @Description VARCHAR(MAX)
DECLARE @Helpfile VARCHAR(MAX)
DECLARE @HelpID INT
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
      @Addendum bit,
      @cda xml,
      @pcdsDocument bit,
      @issuer uniqueidentifier,
      @MRN VARCHAR(50),
      @ExamCode VARCHAR(50),
      @ExamCodeDesc VARCHAR(100)

Declare @ExamCodeDictionary TABLE (
   ExamCode VARCHAR(50),
   ExamCodeDesc VARCHAR(100),
   Modality varchar(50),
   BodyPart varchar(50)
)

IF @Path = ''
BEGIN
   PRINT 'Path must be specified.'
   PRINT 'Please modify the value for the @Path parameter and try again.'
   RETURN
END

DECLARE @file_results table
(
   file_exists int,
   file_is_a_directory int,
    parent_directory_exists int
)

-- Populate the exam code dictionary
INSERT INTO @ExamCodeDictionary (ExamCode, ExamCodeDesc, Modality, BodyPart)
SELECT ExamCode, ExamCodeDesc, Modality, BodyPart
FROM YourExamCodeDictionaryTable -- Replace with your actual exam code dictionary table

Select 'Searching for jobs between ' + convert(nvarchar(12),@begindate) + ' and ' + convert(nvarchar(12),@enddate)

While @begindate < @enddate
Begin
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
            ExamIssuerKey,
            p.MRN
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
                     @issuer,
                     @MRN
   while @@FETCH_STATUS=0
   BEGIN
   If @pcdsDocument=0
   Begin
      select @sectioncnt=@cda.value('declare namespace ns="urn:hl7-org:v3"; count(//ns:structuredBody/ns:component/ns:section)','int')
      if @sectioncnt!=0
      BEGIN
         While @s<=@sectioncnt
         Begin
            select @chars=@chars+(select XTbl.XNodes.value('declare namespace ns="urn:hl7-org:v3"; (ns:title)[1]','nvarchar(30)')
            FROM @cda.nodes('declare namespace ns="urn:hl7-org:v3"; //ns:structuredBody/ns:component[sql:variable("@s")]/ns:section') AS XTbl(XNodes))+char(13)

            select @listitemcnt=@cda.value('declare namespace ns="urn:hl7-org:v3"; count(//ns:structuredBody/ns:component[sql:variable("@s")]/ns:section/ns:text/ns:list/ns:item)','int')
            if @listitemcnt!=0 (Select @chars=@chars)
            While @l<=@listitemcnt
            BEGIN
               select @paragraphcnt=@cda.value('declare namespace ns="urn:hl7-org:v3"; count(//ns:structuredBody/ns:component[sql:variable("@s")]/ns:section/ns:text/ns:list/ns:item[sql:variable("@l")]/ns:paragraph)','int')
               If @paragraphcnt=0 (select @chars=@chars+' ')
               else
               While @p<=@paragraphcnt
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
            set @l=1
            select @paragraphcnt=@cda.value('declare namespace ns="urn:hl7-org:v3"; count(//ns:structuredBody/ns:component[sql:variable("@s")]/ns:section/ns:text/ns:paragraph)','int')
            If @paragraphcnt=0 (select @chars=@chars+' ')
            else
            While @p<=@paragraphcnt
            Begin
               Select @chars=@chars+XTbl.XNodes.value('declare namespace ns="urn:hl7-org:v3"; (.)[1]','varchar(max)')
               FROM @cda.nodes('declare namespace ns="urn:hl7-org:v3"; //ns:structuredBody/ns:component[sql:variable("@s")]/ns:section/ns:text/ns:paragraph[sql:variable("@p")]/ns:content') AS XTbl(XNodes)
               Select @chars=@chars+char(13)
               set @p=@p+1
            End
            set @p=1
            select @subsectioncnt=@cda.value('declare namespace ns="urn:hl7-org:v3"; count(//ns:structuredBody/ns:component[sql:variable("@s")]/ns:component/ns:section)','int')
            While @ss<=@subsectioncnt
            Begin
               select @chars=@chars+'<h4>'+(select XTbl.XNodes.value('declare namespace ns="urn:hl7-org:v3"; (ns:title)[1]','nvarchar(30)')
               FROM @cda.nodes('declare namespace ns="urn:hl7-org:v3"; //ns:structuredBody/ns:component[sql:variable("@s")]/ns:component[sql:variable("@ss")]/ns:section') AS XTbl(XNodes))+'</h4>'
               select @paragraphcnt=(select XTbl.XNodes.value('declare namespace ns="urn:hl7-org:v3"; count(ns:text/ns:paragraph)','int')
                  from @cda.nodes('declare namespace ns="urn:hl7-org:v3"; //ns:structuredBody/ns:component[sql:variable("@s")]/ns:component[sql:variable("@ss")]/ns:section') as XTbl(XNodes))
               If @paragraphcnt=0 (select @chars=@chars+' ') 
               While @p<=@paragraphcnt
               Begin
                  Select @chars=@chars+XTbl.XNodes.value('declare namespace ns="urn:hl7-org:v3"; (.)[1]','varchar(max)')
                  FROM @cda.nodes('declare namespace ns="urn:hl7-org:v3"; //ns:structuredBody/ns:component[sql:variable("@s")]/ns:component[sql:variable("@ss")]/ns:section/ns:text/ns:paragraph[sql:variable("@p")]/ns:content') AS XTbl(XNodes)
                  Select @chars=@chars+char(13)
                  set @p=@p+1
               End
               set @p=1
               set @ss=@ss+1
            End
            set @ss=1
            set @s=@s+1
         End
         set @s=1
      End
      set @s=1
      insert into @z select @job_id, @accession, @Patient_DOB, @CreatedDate, @SignedDate, @ProvFirstName, @ProvLastName, @ProvID, @ContributorId1, @ContributorFirstName1, @ContributorLastName1, @ContributorId2, @ContributorFirstName2, @ContributorLastName2, @Modality, @ProcDesc, @addendum, @chars, @pcdsDocument
      set @String = @String+'<FFIDocument>'
      set @String = @String+'<Filename>'+@accession+'</Filename>'
      set @String = @String+'<DocumentCreateDate>'+convert(nvarchar(19),@CreatedDate)+'</DocumentCreateDate>'
      set @String = @String+'<DocumentSignDate>'+convert(nvarchar(19),@SignedDate)+'</DocumentSignDate>'
      set @String = @String+'<PatientDOB>'+convert(nvarchar(10),@Patient_DOB)+'</PatientDOB>'
      set @String = @String+'<PhysicianFirstName>'+@ProvFirstName+'</PhysicianFirstName>'
      set @String = @String+'<PhysicianLastName>'+@ProvLastName+'</PhysicianLastName>'
      set @String = @String+'<PhysicianID>'+@ProvID+'</PhysicianID>'
      if @addendum=0 set @String = @String+'<Addendum>N</Addendum>' else set @String = @String+'<Addendum>Y</Addendum>'
      set @String = @String+'<PCDSDocumentFlag>'+convert(nvarchar(1),@pcdsDocument)+'</PCDSDocumentFlag>'
      set @String = @String+'<PhysicianID1>'+@ContributorId1+'</PhysicianID1>'
      set @String = @String+'<PhysicianFirstName1>'+@ContributorFirstName1+'</PhysicianFirstName1>'
      set @String = @String+'<PhysicianLastName1>'+@ContributorLastName1+'</PhysicianLastName1>'
      set @String = @String+'<PhysicianID2>'+@ContributorId2+'</PhysicianID2>'
      set @String = @String+'<PhysicianFirstName2>'+@ContributorFirstName2+'</PhysicianFirstName2>'
      set @String = @String+'<PhysicianLastName2>'+@ContributorLastName2+'</PhysicianLastName2>'
      set @String = @String+'<Modality>'+@Modality+'</Modality>'
      set @String = @String+'<ProcedureDescription>'+@ProcDesc+'</ProcedureDescription>'
      set @String = @String+'<Issuer>'+convert(nvarchar(36),@issuer)+'</Issuer>'
      if @pcdsDocument=0
      BEGIN
         set @String = @String+'<Report>'
         set @String = @String+@chars
         set @String = @String+'</Report>'
      END
      set @String = @String+'</FFIDocument>'
      set @String = @String+'<Folder>'+'C:\MModalOutput\'+@accession+'</Folder>'
      set @String = @String+'<Path>'+'C:\MModalOutput\'+@accession+'</Path>'
      set @String = @String+'<SourceObject>'+'C:\MModalOutput\'+@accession+'\'+@accession+'.pdf</SourceObject>'
      set @String = @String+'<DestinationObject>'+'C:\MModalOutput\'+@accession+'\'+@accession+'_Copy.pdf</DestinationObject>'
      set @String = @String+'</FFIDocument>'
      set @String = @String+'<IndexJob>'
      set @String = @String+'<JobIdentifier>'+convert(nvarchar(36),@job_id)+'</JobIdentifier>'
      set @String = @String+'<AccessionNumber>'+@accession+'</AccessionNumber>'
      set @String = @String+'<Issuer>'+convert(nvarchar(36),@issuer)+'</Issuer>'
      set @String = @String+'<SourceObject>'+'C:\MModalOutput\'+@accession+'\'+@accession+'.pdf</SourceObject>'
      set @String = @String+'<DestinationObject>'+'C:\MModalOutput\'+@accession+'\'+@accession+'_Copy.pdf</DestinationObject>'
      set @String = @String+'</IndexJob>'
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
                        @issuer,
                        @MRN
   END
   close c1
   deallocate c1
   set @String = @String+'</FFIDocuments>'
   set @doc = convert(xml,@String)
   insert into FFI_UploadXMLs values(@doc,GETDATE())
   set @begindate=DATEADD(WEEK,1,dateadd(SS,-1,@begindate))
END

SELECT 
   z.job_id, z.accession, z.Patient_DOB, z.CreatedDate, z.SignedDate, z.ProvFirstName, z.ProvLastName, z.ProvID,
   z.ContributorId1, z.ContributorFirstName1, z.ContributorLastName1, z.ContributorId2, z.ContributorFirstName2, z.ContributorLastName2,
   z.Modality, z.ProcDesc, z.Addendum, z.Report, z.PCDSDocumentFlag,
   e.ExamCode, e.ExamCodeDesc, e.Modality, e.BodyPart
FROM @z z
JOIN @ExamCodeDictionary e ON e.ExamCode = z.accession

SELECT * FROM FFI_UploadXMLs
