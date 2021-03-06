USE [SCRA_DB]
GO
/****** Object:  UserDefinedFunction [dbo].[GetDependentTypeName]    Script Date: 06/25/2019 11:49:13 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[GetDependentTypeName] 
(
	@DependentTypeId int
)
RETURNS varchar(16)
AS
BEGIN
	-- Declare the return variable here
	DECLARE @ResultVar varchar(16)

	-- Add the T-SQL statements to compute the return value here
	SET @ResultVar = (SELECT [Type] FROM [SCRA_DB].[dbo].[DependentType] WHERE [ID] = @DependentTypeId);

	-- Return the result of the function
	RETURN @ResultVar

END
GO
/****** Object:  StoredProcedure [dbo].[spInquiries_Report]    Script Date: 06/25/2019 11:49:12 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spInquiries_Report]
	--@ReportDate date
AS
BEGIN

	SET NOCOUNT ON;
	
	--DECLARE @Interval varchar(24)
	--SET @Interval = CONVERT(varchar(10),(DATEADD(ww,datediff(ww,0,dateadd(ww,0,@ReportDate)),0)),101) + ' - ' + CONVERT(varchar(10),(DATEADD(ww,datediff(ww,0,dateadd(ww,0,@ReportDate)),6)),101)
	--PRINT @Interval

	/* INQUIRY */
SELECT DISTINCT i.ID,CAST(CONVERT(VARCHAR(10),[InquiryDate],121) as DATE) as 'RequestDate'
	  ,[InquiryType]
	  ,ISNULL(dbo.fnResponseMethodName(i.[ContactMethodID]),'') as [ContactMethod]
	  ,t.[Status]
	  /*,(SELECT CASE WHEN 
				(SELECT COUNT(*) FROM (SELECT Title, Status,QaCompletionDate,CompletionDate,[Timestamp] FROM dbo.SubTask
					WHERE (TaskID = (SELECT ID FROM Task WHERE InquiryID = i.Id)) AND (Title <> 'Assign QA Agent') AND ([CompletionDate] IS NULL AND [QaCompletionDate] IS NULL)
					GROUP BY Title, Status,QaCompletionDate,CompletionDate,[Timestamp]
						HAVING [Timestamp] = MAX([Timestamp])) th )  > 0 THEN 'in_process'
				ELSE CASE WHEN
				(SELECT COUNT(*) FROM (SELECT Title, Status,QaCompletionDate,CompletionDate,[Timestamp] FROM dbo.SubTask
					WHERE (TaskID = (SELECT ID FROM Task WHERE InquiryID = i.Id)) AND (Title <> 'Assign QA Agent') AND ([CompletionDate] IS NOT NULL AND [QaCompletionDate] IS NULL)
					GROUP BY Title, Status,QaCompletionDate,CompletionDate,[Timestamp]
						HAVING [Timestamp] = MAX([Timestamp])) th ) > 0 THEN 'completed'
				ELSE CASE WHEN 
				(SELECT COUNT(*) FROM (SELECT Title, Status,QaCompletionDate,CompletionDate,[Timestamp] FROM  dbo.SubTask
					WHERE (TaskID = (SELECT ID FROM Task WHERE InquiryID = i.Id)) AND (Title <> 'Assign QA Agent') AND ([CompletionDate] IS NOT NULL AND [QaCompletionDate] IS NOT NULL)
					GROUP BY Title, Status,QaCompletionDate,CompletionDate,[Timestamp]
						HAVING [Timestamp] = MAX([Timestamp])) th ) > 0 THEN 'qa_completed'
				ELSE (SELECT [Status] FROM Task WHERE InquiryID = i.Id)
				END
			END
		END) as [Status]*/		 
	  
	  ,ISNULL(i.PersonInquiringId,'') as [PersonRequestingId]
	  ,ISNULL((SELECT FirstName FROM [dbo].[Person] WHERE [ID] = i.PersonInquiringId),'') as [PersonRequestingFirstName]
	  ,ISNULL((SELECT LastName FROM [dbo].[Person] WHERE [ID] = i.PersonInquiringId),'') as [PersonRequestingLastName]
	  
	  ,ISNULL((SELECT [Email] FROM [dbo].[Person] WHERE [ID] = i.PersonInquiringId),'') as [PersonRequestingEmail]
	  ,ISNULL((SELECT REPLACE([Phone],'0000000000','') FROM [dbo].[Person] WHERE [ID] = i.PersonInquiringId),'') as [PersonRequestingPhone]
	  
	  ,ISNULL((SELECT [Address1] FROM [dbo].[Person] WHERE [ID] = i.PersonInquiringId),'') as [PersonRequestingAddress1]
	  ,ISNULL((SELECT [Address2] FROM [dbo].[Person] WHERE [ID] = i.PersonInquiringId),'') as [PersonRequestingAddress2]
	  ,ISNULL((SELECT [City] FROM [dbo].[Person] WHERE [ID] = i.PersonInquiringId),'') as [PersonRequestingCity]
	  ,ISNULL((SELECT [State] FROM [dbo].[Person] WHERE [ID] = i.PersonInquiringId),'') as [PersonRequestingState]
	  ,ISNULL((SELECT [Zip] FROM [dbo].[Person] WHERE [ID] = i.PersonInquiringId),'') as [PersonRequestingZip]
	  
	  ,ISNULL(CAST(p.Id as varchar(9)),'') as [ServicememberID]
      ,ISNULL(p.FirstName,'') as ServicememberFirstName
      ,ISNULL(p.MiddleInitial,'') as ServicememberMiddleInitial
      ,ISNULL(p.LastName,'') as ServicememberLastName
	  
	  ,ISNULL((SELECT [Email] FROM [dbo].[Person] WHERE [ID] = i.ServicememberId),'') as [ServicememberEmail]
	  ,ISNULL((SELECT REPLACE([Phone],'0000000000','') FROM [dbo].[Person] WHERE [ID] = i.ServicememberId),'') as [ServicememberPhone]
	  
	  ,ISNULL((SELECT [Address1] FROM [dbo].[Person] WHERE [ID] = i.ServicememberId),'') as [ServicememberAddress1]
	  ,ISNULL((SELECT [Address2] FROM [dbo].[Person] WHERE [ID] = i.ServicememberId),'') as [ServicememberAddress2]
	  ,ISNULL((SELECT [City] FROM [dbo].[Person] WHERE [ID] = i.ServicememberId),'') as [ServicememberCity]
	  ,ISNULL((SELECT [State] FROM [dbo].[Person] WHERE [ID] = i.ServicememberId),'') as [ServicememberState]
	  ,ISNULL((SELECT [Zip] FROM [dbo].[Person] WHERE [ID] = i.ServicememberId),'') as [ServicememberZip]
	  
	  ,CASE WHEN i.PersonInquiringId <> p.ID THEN 'Yes' ELSE '' END as 'ServicememberIfDefferent'
	  ,CASE WHEN i.PersonInquiringId <> p.ID THEN 
			COALESCE((SELECT dbo.GetDependentTypename([DependentTypeID]) FROM [dbo].[PersonToPersonLink] WHERE [FromID] = i.PersonInquiringId AND [ToID] = p.ID),
			(SELECT dbo.GetDependentTypename([DependentTypeID]) FROM [dbo].[PersonToPersonLink] WHERE [FromID] = p.ID AND [ToID] = i.PersonInquiringId))
			ELSE '' END as 'Relationship'
  
	  ,ISNULL((SELECT MAX([CompletionDate]) FROM (SELECT CONVERT(varchar(10),MAX(st.CompletionDate),121) as [CompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON tt.ID = st.TaskID AND st.Title = 'Log Request' WHERE tt.ID = t.ID and st.[Status] <> 'rejected' GROUP BY st.CompletionDate HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'') as 'LogRequestDone'
      ,ISNULL((SELECT TOP 1 dbo.fnGetUserName(th.CompletedBy) FROM (SELECT st.CompletedBy as [CompletedBy], MAX(st.CompletionDate) as [CompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON tt.ID = st.TaskID AND st.Title = 'Log Request' WHERE tt.ID = t.ID and st.[Status] <> 'rejected' GROUP BY st.CompletionDate,st.CompletedBy HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'') as 'LogRequestCompletedBy'
   	  
      ,[dbo].DecodeUTF8String(ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE([Description],CHAR(10)+CHAR(13),'|'),CHAR(10),'|'),CHAR(13),'|'),CHAR(9),'    '),'|||','|'),'||','|'),CHAR(226)+CHAR(128)+CHAR(147),'-'),'')) as [Description]
      ,[dbo].DecodeUTF8String(ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE([Comment],CHAR(10)+CHAR(13),'|'),CHAR(10),'|'),CHAR(13),'|'),CHAR(9),'    '),'|||','|'),'||','|'),CHAR(226)+CHAR(128)+CHAR(147),'-'),'')) as [Comment]
      ,[dbo].DecodeUTF8String(ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE([ResponseText],CHAR(10)+CHAR(13),'|'),CHAR(10),'|'),CHAR(13),'|'),CHAR(9),'    '),'|||','|'),'||','|'),CHAR(226)+CHAR(128)+CHAR(147),'-'),'')) as [ResponseText]
      ,ISNULL(CONVERT(VARCHAR(10),[ResponseDate],121),'') as [ResponseDate]
      ,ISNULL(dbo.fnResponseMethodName([ResponseMethodId]),'') as [ResponseMethod]
						
		,CASE WHEN /*(SELECT CASE WHEN 
				(SELECT COUNT(*) FROM (SELECT Title, Status,QaCompletionDate,CompletionDate,[Timestamp] FROM dbo.SubTask
					WHERE (TaskID = (SELECT ID FROM Task WHERE InquiryID = i.Id)) AND (Title <> 'Assign QA Agent') AND ([CompletionDate] IS NULL AND [QaCompletionDate] IS NULL)
					GROUP BY Title, Status,QaCompletionDate,CompletionDate,[Timestamp]
						HAVING [Timestamp] = MAX([Timestamp])) th )  > 0 THEN 'in_process'
				ELSE CASE WHEN
				(SELECT COUNT(*) FROM (SELECT Title, Status,QaCompletionDate,CompletionDate,[Timestamp] FROM dbo.SubTask
					WHERE (TaskID = (SELECT ID FROM Task WHERE InquiryID = i.Id)) AND (Title <> 'Assign QA Agent') AND ([CompletionDate] IS NOT NULL AND [QaCompletionDate] IS NULL)
					GROUP BY Title, Status,QaCompletionDate,CompletionDate,[Timestamp]
						HAVING [Timestamp] = MAX([Timestamp])) th ) > 0 THEN 'completed'
				ELSE CASE WHEN 
				(SELECT COUNT(*) FROM (SELECT Title, Status,QaCompletionDate,CompletionDate,[Timestamp] FROM  dbo.SubTask
					WHERE (TaskID = (SELECT ID FROM Task WHERE InquiryID = i.Id)) AND (Title <> 'Assign QA Agent') AND ([CompletionDate] IS NOT NULL AND [QaCompletionDate] IS NOT NULL)
					GROUP BY Title, Status,QaCompletionDate,CompletionDate,[Timestamp]
						HAVING [Timestamp] = MAX([Timestamp])) th ) > 0 THEN 'qa_completed'
				ELSE (SELECT [Status] FROM Task WHERE InquiryID = i.Id)
				END
			END
		END)*/ t.[Status] IN ('completed','qa_completed','misdirected') THEN 'Yes' ELSE '' END as [Completed]
      
  FROM [dbo].[Inquiry] i
	LEFT JOIN [dbo].[Person] p ON i.ServicememberId = p.ID
	LEFT JOIN [dbo].[Task] t ON i.ID = t.InquiryID
	LEFT JOIN [dbo].[Customer] c ON p.Id = c.PersonID
	LEFT JOIN (SELECT DISTINCT MAX(ad.ID) as ID,PersonID,StartDate,EndDate,NoticeDate,Branch,IsReserve FROM [dbo].[ActiveDuty] ad JOIN [dbo].[BranchOfService] bs ON ad.BranchOfServiceID = bs.ID
			GROUP BY PersonID,StartDate,EndDate,NoticeDate,Branch,IsReserve HAVING StartDate = (SELECT MAX(StartDate) FROM [dbo].[ActiveDuty] ad2 WHERE ad2.PersonID = ad.PersonID) AND 
			(EndDate = (SELECT MAX(EndDate) FROM [dbo].[ActiveDuty] ad2 WHERE ad2.PersonID = ad.PersonID) OR EndDate IS NULL)) ad ON p.ID = ad.PersonID
	LEFT JOIN [dbo].[Contract] con ON p.Id = con.PersonID and con.IsDeleted = 0
	LEFT JOIN [dbo].[ContractType] ct ON con.ContractTypeId = ct.ID
	LEFT JOIN [dbo].[Employee] e ON i.[AgentID] = e.ID
  WHERE [InquiryType] = 'inquiry' AND (con.IsDeleted = 0 or con.IsDeleted IS NULL)
  
  --AND i.PersonInquiringId <> p.ID 
  --AND CASE WHEN i.PersonInquiringId <> p.ID THEN 
		--	COALESCE((SELECT dbo.GetDependentTypename([DependentTypeID]) FROM [dbo].[PersonToPersonLink] WHERE [FromID] = i.PersonInquiringId AND [ToID] = p.ID),
		--	(SELECT dbo.GetDependentTypename([DependentTypeID]) FROM [dbo].[PersonToPersonLink] WHERE [FromID] = p.ID AND [ToID] = i.PersonInquiringId))
		--	ELSE '' END IS NULL
    
  ORDER BY CAST(CONVERT(VARCHAR(10),[InquiryDate],121) as DATE) DESC
  
END


/*

--DECLARE @date date SET @date = dateadd(wk,-1,getdate())
--SELECT @date
EXEC [dbo].[spInquiries_Report]
	--@ReportDate = @date
	
*/
GO
/****** Object:  StoredProcedure [dbo].[spDMDC_Validation_Report]    Script Date: 06/25/2019 11:49:12 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDMDC_Validation_Report]
	--@ReportDate date
AS
BEGIN

	SET NOCOUNT ON;
	
	--DECLARE @Interval varchar(24)
	--SET @Interval = CONVERT(varchar(10),(DATEADD(ww,datediff(ww,0,dateadd(ww,0,@ReportDate)),0)),101) + ' - ' + CONVERT(varchar(10),(DATEADD(ww,datediff(ww,0,dateadd(ww,0,@ReportDate)),6)),101)
	--PRINT @Interval

	/* DMDC */
	SELECT DISTINCT i.ID,CAST(CONVERT(VARCHAR(10),[InquiryDate],121) as DATE) as 'RequestDate'
	  ,[InquiryType]
	  
	  ,COALESCE(/*(SELECT CASE WHEN 
				(SELECT COUNT(*) FROM (SELECT Title, Status,QaCompletionDate,CompletionDate,[Timestamp] FROM dbo.SubTask
					WHERE (TaskID = (SELECT ID FROM Task WHERE InquiryID = i.Id)) AND (Title <> 'Assign QA Agent') AND ([CompletionDate] IS NULL AND [QaCompletionDate] IS NULL)
					GROUP BY Title, Status,QaCompletionDate,CompletionDate,[Timestamp]
						HAVING [Timestamp] = MAX([Timestamp])) th )  > 0 THEN 'in_process'
				ELSE CASE WHEN
				(SELECT COUNT(*) FROM (SELECT Title, Status,QaCompletionDate,CompletionDate,[Timestamp] FROM dbo.SubTask
					WHERE (TaskID = (SELECT ID FROM Task WHERE InquiryID = i.Id)) AND (Title <> 'Assign QA Agent') AND ([CompletionDate] IS NOT NULL AND [QaCompletionDate] IS NULL)
					GROUP BY Title, Status,QaCompletionDate,CompletionDate,[Timestamp]
						HAVING [Timestamp] = MAX([Timestamp])) th ) > 0 THEN 'completed'
				ELSE CASE WHEN 
				(SELECT COUNT(*) FROM (SELECT Title, Status,QaCompletionDate,CompletionDate,[Timestamp] FROM  dbo.SubTask
					WHERE (TaskID = (SELECT ID FROM Task WHERE InquiryID = i.Id)) AND (Title <> 'Assign QA Agent') AND ([CompletionDate] IS NOT NULL AND [QaCompletionDate] IS NOT NULL)
					GROUP BY Title, Status,QaCompletionDate,CompletionDate,[Timestamp]
						HAVING [Timestamp] = MAX([Timestamp])) th ) > 0 THEN 'qa_completed'
				ELSE (SELECT [Status] FROM Task WHERE InquiryID = i.Id)
				END
			END
		END)*/t.[Status], CASE i.[IsCompleted] WHEN 0 THEN 'in_process' WHEN 1 THEN 'completed' ELSE '' END) as [Status]
	  
	  ,ISNULL(i.PersonInquiringId,'') as [PersonRequestingId]
	  ,ISNULL((SELECT FirstName FROM [dbo].[Person] WHERE [ID] = i.PersonInquiringId),'') as [PersonRequestingFirstName]
	  ,ISNULL((SELECT LastName FROM [dbo].[Person] WHERE [ID] = i.PersonInquiringId),'') as [PersonRequestingLastName]
	  
	  ,ISNULL(CAST(p.Id as varchar(9)),'') as [ServicememberID]
      ,ISNULL(p.FirstName,'') as ServicememberFirstName
      ,ISNULL(p.MiddleInitial,'') as ServicememberMiddleInitial
      ,ISNULL(p.LastName,'') as ServicememberLastName
     
	  ,ISNULL((SELECT MAX([CompletionDate]) FROM (SELECT CONVERT(varchar(10),MAX(st.CompletionDate),121) as [CompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON tt.ID = st.TaskID AND st.Title = 'Log Request' WHERE tt.ID = t.ID and st.[Status]<> 'rejected' GROUP BY st.CompletionDate HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'') as 'LogRequestDone'
      ,ISNULL((SELECT TOP 1 dbo.fnGetUserName(th.CompletedBy) FROM (SELECT st.CompletedBy as [CompletedBy], MAX(st.CompletionDate) as [CompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON tt.ID = st.TaskID AND st.Title = 'Log Request' WHERE tt.ID = t.ID and st.[Status]<> 'rejected' GROUP BY st.CompletionDate,st.CompletedBy HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'') as 'LogRequestCompletedBy'
      	      
      ,[dbo].DecodeUTF8String(ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE([Description],CHAR(10)+CHAR(13),'|'),CHAR(10),'|'),CHAR(13),'|'),CHAR(9),'    '),'|||','|'),'')) as [Description]
      ,[dbo].DecodeUTF8String(ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE([Comment],CHAR(10)+CHAR(13),'|'),CHAR(10),'|'),CHAR(13),'|'),CHAR(9),'    '),'|||','|'),'')) as [Comment]
      
      ,[dbo].DecodeUTF8String(ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE([ResponseText],CHAR(10)+CHAR(13),'|'),CHAR(10),'|'),CHAR(13),'|'),CHAR(9),'    '),'|||','|'),'')) as [ResponseText]
      ,ISNULL(CONVERT(VARCHAR(10),[ResponseDate],121),'') as [ResponseDate]
      ,ISNULL(dbo.fnResponseMethodName([ResponseMethodId]),'') as [ResponseMethod]
      
      ,ISNULL(CONVERT(VARCHAR(10),[DMDCValidationDate],121),'') as [DMDCValidationDate]
      
      ,ISNULL(CASE WHEN ad.PersonID IS NOT NULL THEN 'Yes' ELSE '' END,'') as [ServicememberOnActiveDuty]
      
      ,CASE WHEN COALESCE(/*(SELECT CASE WHEN 
				(SELECT COUNT(*) FROM (SELECT Title, Status,QaCompletionDate,CompletionDate,[Timestamp] FROM dbo.SubTask
					WHERE (TaskID = (SELECT ID FROM Task WHERE InquiryID = i.Id)) AND (Title <> 'Assign QA Agent') AND ([CompletionDate] IS NULL AND [QaCompletionDate] IS NULL)
					GROUP BY Title, Status,QaCompletionDate,CompletionDate,[Timestamp]
						HAVING [Timestamp] = MAX([Timestamp])) th )  > 0 THEN 'in_process'
				ELSE CASE WHEN
				(SELECT COUNT(*) FROM (SELECT Title, Status,QaCompletionDate,CompletionDate,[Timestamp] FROM dbo.SubTask
					WHERE (TaskID = (SELECT ID FROM Task WHERE InquiryID = i.Id)) AND (Title <> 'Assign QA Agent') AND ([CompletionDate] IS NOT NULL AND [QaCompletionDate] IS NULL)
					GROUP BY Title, Status,QaCompletionDate,CompletionDate,[Timestamp]
						HAVING [Timestamp] = MAX([Timestamp])) th ) > 0 THEN 'completed'
				ELSE CASE WHEN 
				(SELECT COUNT(*) FROM (SELECT Title, Status,QaCompletionDate,CompletionDate,[Timestamp] FROM  dbo.SubTask
					WHERE (TaskID = (SELECT ID FROM Task WHERE InquiryID = i.Id)) AND (Title <> 'Assign QA Agent') AND ([CompletionDate] IS NOT NULL AND [QaCompletionDate] IS NOT NULL)
					GROUP BY Title, Status,QaCompletionDate,CompletionDate,[Timestamp]
						HAVING [Timestamp] = MAX([Timestamp])) th ) > 0 THEN 'qa_completed'
				ELSE (SELECT [Status] FROM Task WHERE InquiryID = i.Id)
				END
			END
		END)*/t.[Status], CASE i.[IsCompleted] WHEN 0 THEN 'in_process' WHEN 1 THEN 'completed' ELSE '' END) IN ('completed','qa_completed','misdirected') THEN 'Yes' ELSE '' END as [Completed]
      
      /* CHANGE LATER, WHEN TASK ARE GENERATED */
      --,CASE WHEN (SELECT TOP 1 [Status] FROM dbo.SubTask WHERE TaskId = (SELECT ID FROM dbo.Task WHERE InquiryID = i.ID) GROUP BY [Title],[Status],[Timestamp] 
						--HAVING [Timestamp] = MAX([Timestamp]) AND [Title] <> 'Assign QA Agent' ORDER BY [Timestamp] DESC) IN ('completed','qa_completed','misdirected') THEN 'Yes' ELSE '' END as [Completed]
      
	FROM [dbo].[Inquiry] i
		LEFT JOIN [dbo].[Person] p ON i.ServicememberId = p.ID
		LEFT JOIN [dbo].[Task] t ON i.ID = t.InquiryID
		LEFT JOIN [dbo].[Customer] c ON p.Id = c.PersonID
		LEFT JOIN (SELECT DISTINCT MAX(ad.ID) as ID,PersonID,StartDate,EndDate,NoticeDate,Branch,IsReserve FROM [dbo].[ActiveDuty] ad JOIN [dbo].[BranchOfService] bs ON ad.BranchOfServiceID = bs.ID
				GROUP BY PersonID,StartDate,EndDate,NoticeDate,Branch,IsReserve HAVING StartDate = (SELECT MAX(StartDate) FROM [dbo].[ActiveDuty] ad2 WHERE ad2.PersonID = ad.PersonID) AND 
				(EndDate = (SELECT MAX(EndDate) FROM [dbo].[ActiveDuty] ad2 WHERE ad2.PersonID = ad.PersonID) OR EndDate IS NULL)) ad ON p.ID = ad.PersonID
		LEFT JOIN [dbo].[Contract] con ON p.Id = con.PersonID
		LEFT JOIN [dbo].[ContractType] ct ON con.ContractTypeId = ct.ID
		LEFT JOIN [dbo].[Employee] e ON i.[AgentID] = e.ID

	  WHERE [InquiryType] = 'dmdc_check' --and COALESCE(t.[Status], CASE i.[IsCompleted] WHEN 0 THEN 'in_process' WHEN 1 THEN 'completed' ELSE '' END) = 'in_process'
	  ORDER BY CAST(CONVERT(VARCHAR(10),[InquiryDate],121) as DATE) DESC


END


/*

--DECLARE @date date SET @date = dateadd(wk,-1,getdate())
--SELECT @date
EXEC [dbo].[spDMDC_Validation_Report]
	--@ReportDate = @date
	
*/
GO
/****** Object:  StoredProcedure [dbo].[spAffiliate_Report]    Script Date: 06/25/2019 11:49:12 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spAffiliate_Report]
	--@ReportDate date
AS
BEGIN

	SET NOCOUNT ON;
	
	--DECLARE @Interval varchar(24)
	--SET @Interval = CONVERT(varchar(10),(DATEADD(ww,datediff(ww,0,dateadd(ww,0,@ReportDate)),0)),101) + ' - ' + CONVERT(varchar(10),(DATEADD(ww,datediff(ww,0,dateadd(ww,0,@ReportDate)),6)),101)
	--PRINT @Interval

	/* AFFILIATE */
	SELECT DISTINCT i.ID,CAST(CONVERT(VARCHAR(10),[InquiryDate],121) as DATE) as 'RequestDate'
	  ,i.[InquiryType]
	  ,ISNULL(dbo.fnResponseMethodName(i.[ContactMethodID]),'') as [ContactMethod]
	  ,t.[Status]
	  --,COALESCE((SELECT TOP 1 [Status] FROM dbo.SubTask WHERE TaskId = (SELECT ID FROM dbo.Task WHERE InquiryID = i.ID) GROUP BY [Title],[Status],[Timestamp] 
			--	 HAVING [Timestamp] = MAX([Timestamp]) AND [Title] <> 'Assign QA Agent' ORDER BY [Timestamp] DESC), CASE [IsCompleted] WHEN 0 THEN 'in_process' WHEN 1 THEN 'completed' ELSE '' END) as [Status]
	  
	  /*,(SELECT CASE WHEN 
				(SELECT COUNT(*) FROM (SELECT Title, Status,QaCompletionDate,CompletionDate,[Timestamp] FROM dbo.SubTask
					WHERE (TaskID = (SELECT ID FROM Task WHERE InquiryID = i.Id)) AND (Title <> 'Assign QA Agent') AND ([CompletionDate] IS NULL AND [QaCompletionDate] IS NULL)
					GROUP BY Title, Status,QaCompletionDate,CompletionDate,[Timestamp]
						HAVING [Timestamp] = MAX([Timestamp])) th )  > 0 THEN 'in_process'
				ELSE CASE WHEN
				(SELECT COUNT(*) FROM (SELECT Title, Status,QaCompletionDate,CompletionDate,[Timestamp] FROM dbo.SubTask
					WHERE (TaskID = (SELECT ID FROM Task WHERE InquiryID = i.Id)) AND (Title <> 'Assign QA Agent') AND ([CompletionDate] IS NOT NULL AND [QaCompletionDate] IS NULL)
					GROUP BY Title, Status,QaCompletionDate,CompletionDate,[Timestamp]
						HAVING [Timestamp] = MAX([Timestamp])) th ) > 0 THEN 'completed'
				ELSE CASE WHEN 
				(SELECT COUNT(*) FROM (SELECT Title, Status,QaCompletionDate,CompletionDate,[Timestamp] FROM  dbo.SubTask
					WHERE (TaskID = (SELECT ID FROM Task WHERE InquiryID = i.Id)) AND (Title <> 'Assign QA Agent') AND ([CompletionDate] IS NOT NULL AND [QaCompletionDate] IS NOT NULL)
					GROUP BY Title, Status,QaCompletionDate,CompletionDate,[Timestamp]
						HAVING [Timestamp] = MAX([Timestamp])) th ) > 0 THEN 'qa_completed'
				ELSE (SELECT [Status] FROM Task WHERE InquiryID = i.Id)
				END
			END
		END) as [Status]*/
	  	  
	  ,ISNULL(i.PersonInquiringId,'') as [PersonRequestingId]
	  ,ISNULL((SELECT FirstName FROM [dbo].[Person] WHERE [ID] = i.PersonInquiringId),'') as [PersonRequestingFirstName]
	  ,ISNULL((SELECT LastName FROM [dbo].[Person] WHERE [ID] = i.PersonInquiringId),'') as [PersonRequestingLastName]
	  
	  ,ISNULL((SELECT [Email] FROM [dbo].[Person] WHERE [ID] = i.PersonInquiringId),'') as [PersonRequestingEmail]
	  ,ISNULL((SELECT REPLACE([Phone],'0000000000','') FROM [dbo].[Person] WHERE [ID] = i.PersonInquiringId),'') as [PersonRequestingPhone]
	  
	  ,ISNULL((SELECT [Address1] FROM [dbo].[Person] WHERE [ID] = i.PersonInquiringId),'') as [PersonRequestingAddress1]
	  ,ISNULL((SELECT [Address2] FROM [dbo].[Person] WHERE [ID] = i.PersonInquiringId),'') as [PersonRequestingAddress2]
	  ,ISNULL((SELECT [City] FROM [dbo].[Person] WHERE [ID] = i.PersonInquiringId),'') as [PersonRequestingCity]
	  ,ISNULL((SELECT [State] FROM [dbo].[Person] WHERE [ID] = i.PersonInquiringId),'') as [PersonRequestingState]
	  ,ISNULL((SELECT [Zip] FROM [dbo].[Person] WHERE [ID] = i.PersonInquiringId),'') as [PersonRequestingZip]
	  
	  ,ISNULL(CAST(p.Id as varchar(9)),'') as [ServicememberID]
      ,ISNULL(p.FirstName,'') as ServicememberFirstName
      ,ISNULL(p.MiddleInitial,'') as ServicememberMiddleInitial
      ,ISNULL(p.LastName,'') as ServicememberLastName
      
      ,ISNULL((SELECT [Email] FROM [dbo].[Person] WHERE [ID] = i.ServicememberId),'') as [ServicememberEmail]
	  ,ISNULL((SELECT REPLACE([Phone],'0000000000','') FROM [dbo].[Person] WHERE [ID] = i.ServicememberId),'') as [ServicememberPhone]
	  
	  ,ISNULL((SELECT [Address1] FROM [dbo].[Person] WHERE [ID] = i.ServicememberId),'') as [ServicememberAddress1]
	  ,ISNULL((SELECT [Address2] FROM [dbo].[Person] WHERE [ID] = i.ServicememberId),'') as [ServicememberAddress2]
	  ,ISNULL((SELECT [City] FROM [dbo].[Person] WHERE [ID] = i.ServicememberId),'') as [ServicememberCity]
	  ,ISNULL((SELECT [State] FROM [dbo].[Person] WHERE [ID] = i.ServicememberId),'') as [ServicememberState]
	  ,ISNULL((SELECT [Zip] FROM [dbo].[Person] WHERE [ID] = i.ServicememberId),'') as [ServicememberZip]
     
      ,ISNULL((SELECT MAX([CompletionDate]) FROM (SELECT CONVERT(varchar(10),MAX(st.CompletionDate),121) as [CompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON tt.ID = st.TaskID AND st.Title = 'Log Request' WHERE tt.ID = t.ID and st.[Status] <> 'rejected' GROUP BY st.CompletionDate HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'') as 'LogRequestDone'
      ,ISNULL((SELECT TOP 1 dbo.fnGetUserName(th.CompletedBy) FROM (SELECT st.CompletedBy as [CompletedBy], MAX(st.CompletionDate) as [CompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON tt.ID = st.TaskID AND st.Title = 'Log Request' WHERE tt.ID = t.ID and st.[Status] <> 'rejected' GROUP BY st.CompletionDate,st.CompletedBy HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'') as 'LogRequestCompletedBy'
   	  
      ,[dbo].DecodeUTF8String(ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE([Description],CHAR(10)+CHAR(13),'|'),CHAR(10),'|'),CHAR(13),'|'),CHAR(9),'    '),'|||','|'),'||','|'),CHAR(226)+CHAR(128)+CHAR(147),'-'),'')) as [Description]
      ,[dbo].DecodeUTF8String(ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE([Comment],CHAR(10)+CHAR(13),'|'),CHAR(10),'|'),CHAR(13),'|'),CHAR(9),'    '),'|||','|'),'||','|'),CHAR(226)+CHAR(128)+CHAR(147),'-'),'')) as [Comment]
      ,[dbo].DecodeUTF8String(ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE([ResponseText],CHAR(10)+CHAR(13),'|'),CHAR(10),'|'),CHAR(13),'|'),CHAR(9),'    '),'|||','|'),'||','|'),CHAR(226)+CHAR(128)+CHAR(147),'-'),'')) as [ResponseText]
      ,ISNULL(CONVERT(VARCHAR(10),[ResponseDate],121),'') as [ResponseDate]
      ,ISNULL(dbo.fnResponseMethodName([ResponseMethodId]),'') as [ResponseMethod]
      
      ,ISNULL(CONVERT(VARCHAR(10),i.ScusaSentDate1,121),'') as ScusaSentDate1
      ,ISNULL(CONVERT(VARCHAR(10),i.ScusaSentDate2,121),'') as ScusaSentDate2
      ,ISNULL(CONVERT(VARCHAR(10),i.ScusaConfirmationDate,121),'') as ScusaConfirmationDate
      
      ,CASE WHEN /*(SELECT CASE WHEN 
				(SELECT COUNT(*) FROM (SELECT Title, Status,QaCompletionDate,CompletionDate,[Timestamp] FROM dbo.SubTask
					WHERE (TaskID = (SELECT ID FROM Task WHERE InquiryID = i.Id)) AND (Title <> 'Assign QA Agent') AND ([CompletionDate] IS NULL AND [QaCompletionDate] IS NULL)
					GROUP BY Title, Status,QaCompletionDate,CompletionDate,[Timestamp]
						HAVING [Timestamp] = MAX([Timestamp])) th )  > 0 THEN 'in_process'
				ELSE CASE WHEN
				(SELECT COUNT(*) FROM (SELECT Title, Status,QaCompletionDate,CompletionDate,[Timestamp] FROM dbo.SubTask
					WHERE (TaskID = (SELECT ID FROM Task WHERE InquiryID = i.Id)) AND (Title <> 'Assign QA Agent') AND ([CompletionDate] IS NOT NULL AND [QaCompletionDate] IS NULL)
					GROUP BY Title, Status,QaCompletionDate,CompletionDate,[Timestamp]
						HAVING [Timestamp] = MAX([Timestamp])) th ) > 0 THEN 'completed'
				ELSE CASE WHEN 
				(SELECT COUNT(*) FROM (SELECT Title, Status,QaCompletionDate,CompletionDate,[Timestamp] FROM  dbo.SubTask
					WHERE (TaskID = (SELECT ID FROM Task WHERE InquiryID = i.Id)) AND (Title <> 'Assign QA Agent') AND ([CompletionDate] IS NOT NULL AND [QaCompletionDate] IS NOT NULL)
					GROUP BY Title, Status,QaCompletionDate,CompletionDate,[Timestamp]
						HAVING [Timestamp] = MAX([Timestamp])) th ) > 0 THEN 'qa_completed'
				ELSE (SELECT [Status] FROM Task WHERE InquiryID = i.Id)
				END
			END
		END)*/ t.[Status] IN ('completed','qa_completed','misdirected') THEN 'Yes' ELSE '' END as [Completed]						
						
  FROM [dbo].[Inquiry] i
	LEFT JOIN [dbo].[Person] p ON i.ServicememberId = p.ID
	LEFT JOIN [dbo].[Task] t ON i.ID = t.InquiryID
	LEFT JOIN [dbo].[Customer] c ON p.Id = c.PersonID
	LEFT JOIN (SELECT DISTINCT MAX(ad.ID) as ID,PersonID,StartDate,EndDate,NoticeDate,Branch,IsReserve FROM [dbo].[ActiveDuty] ad JOIN [dbo].[BranchOfService] bs ON ad.BranchOfServiceID = bs.ID
			GROUP BY PersonID,StartDate,EndDate,NoticeDate,Branch,IsReserve HAVING StartDate = (SELECT MAX(StartDate) FROM [dbo].[ActiveDuty] ad2 WHERE ad2.PersonID = ad.PersonID) AND 
			(EndDate = (SELECT MAX(EndDate) FROM [dbo].[ActiveDuty] ad2 WHERE ad2.PersonID = ad.PersonID) OR EndDate IS NULL)) ad ON p.ID = ad.PersonID
	LEFT JOIN [dbo].[Contract] con ON p.Id = con.PersonID and con.IsDeleted = 0
	LEFT JOIN [dbo].[ContractType] ct ON con.ContractTypeId = ct.ID
	LEFT JOIN [dbo].[Employee] e ON i.[AgentID] = e.ID
  WHERE [InquiryType] = 'affiliate' AND (con.IsDeleted = 0 or con.IsDeleted IS NULL)
  ORDER BY CAST(CONVERT(VARCHAR(10),[InquiryDate],121) as DATE) DESC
  
END


/*

--DECLARE @date date SET @date = dateadd(wk,-1,getdate())
--SELECT @date
EXEC [dbo].[spAffiliate_Report]
	--@ReportDate = @date
	
*/
GO
