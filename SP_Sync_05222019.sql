USE [SCRA_DB]
GO
/****** Object:  StoredProcedure [dbo].[spTaskStatus_Report]    Script Date: 05/22/2019 10:19:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spTaskStatus_Report] 
	@Interval	VARCHAR(7),
	@ReportDate DATE = NULL,
	@TaskType	VARCHAR(24) = ''
WITH RECOMPILE
AS
BEGIN
	
	SET NOCOUNT ON;
	
	DECLARE @sql varchar(max)
	
	SET @sql = '	
	SELECT CreateDate as ''Date'',
		CASE TaskType 
			WHEN ''request_dmdc_check'' THEN ''DMDC Validation'' 
			WHEN ''request_inquiry''	THEN ''Inquiry''
			WHEN ''request_affiliate''	THEN ''Affilliate or SBO''
			WHEN ''request_benefits''	THEN ''Benefit Request and Eligibility Determination''
			WHEN ''add_benefit''		THEN ''Add Benefit''
			WHEN ''remove_benefit''		THEN ''Remove Benefit''
			WHEN ''deny_benefit''		THEN ''Deny Benefit''
			ELSE '''' END as ''Task Type'',
		ISNULL([in_process],'''')	AS ''In Process'',
		ISNULL([completed],'''')	AS ''Completed'',
		ISNULL([qa_completed],'''') AS ''QA Completed'',
		ISNULL([rejected],'''')		AS ''Rejected'',
		ISNULL([misdirected],'''')	AS ''Misdirected'',
		ISNULL([in_process],'''') + 
		ISNULL([completed],'''') + 
		ISNULL([qa_completed],'''') + 
		ISNULL([rejected],'''') + 
		ISNULL([misdirected],'''') AS ''Total''
	FROM (
	SELECT CONVERT(varchar(10), CreateDate, 101) AS CreateDate,TaskType,[Status], COUNT(*) as cnt FROM Task 
		WHERE 1 = 1
	'
	
	IF @Interval = 'Weekly' BEGIN
		SET @sql = @sql + '
		AND [CreateDate] BETWEEN DATEADD(ww,datediff(ww,0,dateadd(ww,0,''' + CONVERT(VARCHAR(10),@ReportDate,101) + ''')),0) AND 
								 DATEADD(ww,datediff(ww,0,dateadd(ww,0,''' + CONVERT(VARCHAR(10),@ReportDate,101) + ''')),6) '
	END
	IF @Interval = 'Monthly' BEGIN
		SET @sql = @sql + '
		AND [CreateDate] BETWEEN CAST(CONVERT(VARCHAR,DATEADD(d,-(day(''' + CONVERT(VARCHAR(10),@ReportDate,101) + ''')-1),''' + CONVERT(VARCHAR(10),@ReportDate,101) + '''),106) as DATE) AND
								 CAST(CONVERT(VARCHAR,DATEADD(d,-(day(DATEADD(m,1,''' + CONVERT(VARCHAR(10),@ReportDate,101) + '''))),DATEADD(m,1,''' + CONVERT(VARCHAR(10),@ReportDate,101) + ''')),106) as DATE) '
	END									
	IF @TaskType NOT IN ('','all') BEGIN
		SET @sql = @sql + '
			AND TaskType = ''' + @TaskType + ''' '
	END
	SET @sql = @sql + '
	GROUP BY CONVERT(varchar(10), CreateDate, 101),TaskType,[Status]
	) src
	PIVOT
	(
	SUM(cnt) for [Status] IN ([in_process],[completed],[qa_completed],[rejected],[misdirected])
	) pvt
	ORDER BY CONVERT(varchar(10), CreateDate, 101) DESC,  
		CASE TaskType 
			WHEN ''request_dmdc_check'' THEN ''DMDC Validation'' 
			WHEN ''request_inquiry''	THEN ''Inquiry''
			WHEN ''request_affiliate''	THEN ''Affilliate or SBO''
			WHEN ''request_benefits''	THEN ''Benefit Request and Eligibility Determination''
			WHEN ''add_benefit''		THEN ''Add Benefit''
			WHEN ''remove_benefit''		THEN ''Remove Benefit''
			WHEN ''deny_benefit''		THEN ''Deny Benefit''
			ELSE '''' END 
'

PRINT @sql

EXEC (@sql)	 

END

/*
DECLARE @Date as date SET @Date = dateadd(wk,-1,getdate())
EXEC [dbo].[spTaskStatus_Report] @Interval = N'Monthly',@ReportDate=@Date
*/
GO
/****** Object:  StoredProcedure [dbo].[spNote_Get]    Script Date: 05/22/2019 10:19:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spNote_Get]
	@PersonID	INT
AS
BEGIN
	SET NOCOUNT ON;

	SELECT * FROM 
	(
		SELECT 
			n.[Comment], 
			n.[Timestamp], 
			n.[ModifiedBy], 
			(SELECT [Name] FROM [dbo].[Employee] 
				WHERE [ID] = n.[ModifiedBy]) as 'ModifiedByName'
			FROM [dbo].[Note] n 
				WHERE [PersonID] = @PersonID 
			
	--UNION
		
	--	SELECT 
	--		i.[Description] as [Comment],
	--		i.[Timestamp],
	--		i.[ModifiedBy],
	--		(SELECT [Name] FROM [dbo].[Employee] 
	--			WHERE [ID] = i.[ModifiedBy]) as 'ModifiedByName' 
	--		FROM [dbo].[Inquiry] i
	--			WHERE i.[ServicememberId] = @PersonID 
	) u
	ORDER BY [Timestamp] DESC
			
END
GO
/****** Object:  StoredProcedure [dbo].[spServicemember_Promo_Rate_End_Report]    Script Date: 05/22/2019 10:19:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spServicemember_Promo_Rate_End_Report]
WITH RECOMPILE
AS
	SET NOCOUNT ON;
--	;with CTE AS (
--	SELECT DISTINCT sm.PersonID,s.DateOfContact,s.MethodOfNotification,s.DateDMDCSearchPerformed,s.VerifyBySCRAOrMilOrders
--				,s.ActiveAccountEligible,s.BenefitApprovedDeniedPending,s.StatusCode
--				,s.NotEligReason,s.DenialReason,s.[90DayLetterSentOn]
--	FROM [SCRA_DB_MIGRATE].[dbo].[Sample] s 
--	JOIN [dbo].[Servicemember] sm ON s.ServiceMemberID = sm.ServicememberID
--	) 
--	SELECT DISTINCT
--	 CAST(com.CommunicationDate	as DATE)	AS DateOfContact
--		,p.ID								AS ServiceMemberID
--		,p.LastName							AS ServicememberLastName
--		,p.FirstName						AS ServicememberFirstname
--		,p.MiddleInitial					AS ServicememberMiddleInitial
--		,cust.FNumber
--		,p.SSN								AS SocialSecurityNumber
--		,p.DOB								AS DateOfBirth
--		,bos.Branch							AS BranchOfService
--		,ad.StartDate						AS ADStartDate
--		,ad.EndDate							AS ADEndDate
--		,cte.BenefitApprovedDeniedPending	AS BenefitApprovedDeniedPending
--		,bd.BenefitAppliedDate				AS DateBenefitsApplied
--		,bd.BenefitRemovedDate				AS DateBenefitsEnded
--		--,ct.CATEGORY_ORIGIN
--		,CASE WHEN ct.SCRA_Code = 'auto' THEN 'Auto'
--			  WHEN ct.SCRA_Code = 'commercial' THEN 'Commercial Loan'
--			  WHEN ct.SCRA_Code = 'consumer_loan' THEN 'Consumer Loan'
--			  WHEN ct.SCRA_Code = 'credit_card' THEN 'Credit Card'
--			  WHEN ct.SCRA_Code = 'mortgage' THEN 'Mortgage'
--			  WHEN ct.SCRA_Code = 'safe_dep_box' THEN 'Safe Deposit Box'
--			  WHEN ISNULL(ct.SCRA_Code,'') = '' THEN ''
--			  ELSE 'Other' END
--											AS ProductType
--		,ct.SUB_PRODUCT_NAME				AS SubType
--		,COALESCE(
--			CASE 
--				WHEN ISNULL(cnt.LegacyNo,'') = '' 
--				THEN NULL 
--				ELSE cnt.LegacyNo END,
--			CASE 
--				WHEN ISNULL(cnt.CardNo,'') = '' 
--				THEN NULL 
--				ELSE cnt.CardNo END,
--			CASE 
--				WHEN ISNULL(cnt.ContractNo,'') = '' 
--				THEN NULL 
--				ELSE cnt.ContractNo END)	AS AccountNum
--		,cnt.OpenDate						AS StartDate
--		,cnt.CloseDate						AS EndDate
--		,cte.ActiveAccountEligible			AS ActiveAccountEligible
--		,REPLACE(REPLACE(REPLACE(note.Comment,CHAR(13)+CHAR(10),'|'),CHAR(34),''''''),CHAR(9),' ') AS Comments
--		,REPLACE(REPLACE(REPLACE(note.Comment,CHAR(13)+CHAR(10),'|'),CHAR(34),''''''),CHAR(9),' ') AS AdditionalComments
--		,bd.PromotionEndDate				AS [Promo Rate End Date]
--	FROM dbo.Person p 
--		INNER JOIN dbo.Communication com 
--			ON com.PersonID=p.ID
--		INNER JOIN dbo.ContactMethod cm 
--			ON com.ContactMethodId=cm.ID
--		INNER JOIN dbo.Customer cust 
--			ON cust.PersonID=p.ID
--		LEFT JOIN dbo.Note note 
--			ON note.PersonID=p.ID
--		INNER JOIN dbo.Benefit b 
--			ON com.BenefitID=b.ID
--		LEFT JOIN dbo.BenefitDetail bd 
--			ON b.ID=bd.BenefitId
--		LEFT JOIN dbo.[Contract] cnt ON cnt.ID=b.ContractID
--		INNER JOIN dbo.ContractType ct ON cnt.ContractTypeId=ct.ID
--		LEFT JOIN dbo.ActiveDuty ad ON ad.PersonID=p.ID
--		INNER JOIN dbo.BranchOfService bos ON ad.BranchOfServiceID=bos.ID
--		LEFT JOIN dbo.Letter_DATA ld ON ld.ID=com.LetterId
		
--		LEFT JOIN CTE cte ON p.ID = cte.PersonID
		
--		OUTER APPLY (SELECT CASE WHEN inq.DMDCValidationDate IS NULL 
--						THEN inq.InquiryDate ELSE inq.DMDCValidationDate END AS DMDCValidationDate 
--							FROM dbo.Inquiry inq inner join dbo.Task task 
--								ON inq.ID = task.InquiryID 
--							WHERE inq.InquiryType='dmdc_check' and task.ID=com.TaskId) dmdc
--		WHERE ISNULL(bd.PromotionEndDate,'') <> ''

--ORDER BY CAST(com.CommunicationDate	as DATE) DESC	

;with CTE AS (
	SELECT DISTINCT sm.PersonID,s.DateOfContact,s.MethodOfNotification,s.DateDMDCSearchPerformed,s.VerifyBySCRAOrMilOrders
				,s.ActiveAccountEligible,s.BenefitApprovedDeniedPending,s.StatusCode
				,s.NotEligReason,s.DenialReason,s.[90DayLetterSentOn]
	FROM [SCRA_DB_MIGRATE].[dbo].[Sample] s 
	JOIN [dbo].[Servicemember] sm ON s.ServiceMemberID = sm.ServicememberID
	) 
	SELECT DISTINCT
		--CAST(com.CommunicationDate	as DATE)	AS DateOfContact
		COALESCE(cast(cte.DateOfContact as date), 
					CASE WHEN cast(p.[Timestamp] as date) = '2019-02-15' THEN NULL ELSE cast(p.[timestamp] as date) END,
					com.CommunicationDate)	
				  							AS DateOfContact
		,p.ID								AS ServiceMemberID
		,p.LastName							AS ServicememberLastName
		,p.FirstName						AS ServicememberFirstname
		,p.MiddleInitial					AS ServicememberMiddleInitial
		,cust.FNumber
		,p.SSN								AS SocialSecurityNumber
		,p.DOB								AS DateOfBirth
		,bos.Branch							AS BranchOfService
		,ad.StartDate						AS ADStartDate
		,ad.EndDate							AS ADEndDate
		,cte.BenefitApprovedDeniedPending	AS BenefitApprovedDeniedPending
		,bd.BenefitAppliedDate				AS DateBenefitsApplied
		,bd.BenefitRemovedDate				AS DateBenefitsEnded
		--,ct.CATEGORY_ORIGIN
		,CASE WHEN ct.SCRA_Code = 'auto' THEN 'Auto'
			  WHEN ct.SCRA_Code = 'commercial' THEN 'Commercial Loan'
			  WHEN ct.SCRA_Code = 'consumer_loan' THEN 'Consumer Loan'
			  WHEN ct.SCRA_Code = 'credit_card' THEN 'Credit Card'
			  WHEN ct.SCRA_Code = 'mortgage' THEN 'Mortgage'
			  WHEN ct.SCRA_Code = 'safe_dep_box' THEN 'Safe Deposit Box'
			  WHEN ISNULL(ct.SCRA_Code,'') = '' THEN ''
			  ELSE 'Other' END
											AS ProductType
		,ct.SUB_PRODUCT_NAME				AS SubType
		,COALESCE(
			CASE 
				WHEN ISNULL(cnt.LegacyNo,'') = '' 
				THEN NULL 
				ELSE cnt.LegacyNo END,
			CASE 
				WHEN ISNULL(cnt.CardNo,'') = '' 
				THEN NULL 
				ELSE cnt.CardNo END,
			CASE 
				WHEN ISNULL(cnt.ContractNo,'') = '' 
				THEN NULL 
				ELSE cnt.ContractNo END)	AS AccountNum
		,cnt.OpenDate						AS StartDate
		,cnt.CloseDate						AS EndDate
		,cte.ActiveAccountEligible			AS ActiveAccountEligible
		,REPLACE(REPLACE(REPLACE(note.Comment,CHAR(13)+CHAR(10),'|'),CHAR(34),''''''),CHAR(9),' ') AS Comments
		,REPLACE(REPLACE(REPLACE(note.Comment,CHAR(13)+CHAR(10),'|'),CHAR(34),''''''),CHAR(9),' ') AS AdditionalComments
		,bd.PromotionEndDate				AS [Promo Rate End Date]
	FROM dbo.Person p 
		outer apply(Select distinct FNumber from dbo.Customer where PersonID=p.ID and PersonID in (Select pp.ID As PersonId from Person pp 
						where ( pp.ID = p.ID OR pp.ID IN (Select ServicememberId from dbo.Inquiry i WHERE i.ServicememberId = p.ID )))) cust
						
		outer apply( Select distinct ID,CommunicationDate,LetterId,TaskId,PersonId,BenefitID from dbo.Communication where PersonID in (Select pp.ID As PersonId from Person pp 
							where ( pp.ID = p.ID OR pp.ID IN (Select ServicememberId from dbo.Inquiry i WHERE i.ServicememberId = p.ID )))) com
							
		outer apply (Select distinct  ContactMethodID from dbo.Inquiry where COALESCE(ServicememberId,PersonInquiringId) in (Select pp.ID As PersonId from Person pp 
							where ( pp.ID = p.ID OR pp.ID IN (Select ServicememberId from dbo.Inquiry i WHERE i.ServicememberId = p.ID )))) r
			LEFT JOIN dbo.ContactMethod cm 
				ON r.ContactMethodId = cm.ID
				
		outer apply (Select * from dbo.ActiveDuty a where a.PersonID in (Select pp.ID As PersonId from Person pp 
							where ( pp.ID = p.ID OR pp.ID IN (Select ServicememberId from dbo.Inquiry i WHERE i.ServicememberId = p.ID )))) ad
			INNER JOIN dbo.BranchOfService bos 
				ON bos.ID = ad.BranchOfServiceID
				
		outer apply (select * from dbo.Benefit bb where bb.PersonID in (Select pp.ID As PersonId from Person pp 
							where ( pp.ID = p.ID OR pp.ID IN (Select ServicememberId from dbo.Inquiry i WHERE i.ServicememberId = p.ID ))
									AND bb.ContractID IN (SELECT ID FROM dbo.[Contract] WHERE PersonID = p.ID and ID = bb.ContractID)
									AND bb.ActiveDutyID IN (SELECT ID FROM ActiveDuty WHERE PersonID = p.ID AND ID = ad.ID) )) b
			 LEFT JOIN dbo.BenefitDetail bd 
				ON b.ID = bd.BenefitId
				
		outer apply (select * from dbo.[Contract] c where b.ContractID = c.ID AND c.IsDeleted = 0 AND c.PersonID in (Select pp.ID As PersonId from Person pp 
							where ( pp.ID = p.ID OR pp.ID IN (Select ServicememberId from dbo.Inquiry i WHERE i.ServicememberId = p.ID ))
							AND c.ID = b.ContractID)) cnt
			LEFT JOIN dbo.ContractType ct 
				ON cnt.ContractTypeId = ct.ID	
				
		outer apply(select distinct Comment from dbo.Note where PersonID in (Select pp.ID As PersonId from Person pp 
							where ( pp.ID = p.ID OR pp.ID IN (Select ServicememberId from dbo.Inquiry i WHERE i.ServicememberId = p.ID )))) note
		
		LEFT JOIN CTE cte ON p.ID = cte.PersonID

		WHERE ISNULL(bd.PromotionEndDate,'') <> ''
		
ORDER BY COALESCE(cast(cte.DateOfContact as date), 
			CASE WHEN cast(p.[Timestamp] as date) = '2019-02-15' THEN NULL ELSE cast(p.[timestamp] as date) END,
					com.CommunicationDate)	 DESC	

/*
EXEC [dbo].[spServicemember_Promo_Rate_End_Report]
*/
GO
/****** Object:  StoredProcedure [dbo].[spServicemember_Monthly_Incoming_GN_Letter_Sent_Report]    Script Date: 05/22/2019 10:19:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spServicemember_Monthly_Incoming_GN_Letter_Sent_Report]
WITH RECOMPILE
AS

	SET NOCOUNT ON;
	;with CTE AS (
	SELECT DISTINCT sm.PersonID,s.DateOfContact,s.MethodOfNotification,s.DateDMDCSearchPerformed,s.VerifyBySCRAOrMilOrders
				,s.ActiveAccountEligible,s.BenefitApprovedDeniedPending,s.StatusCode
				,s.NotEligReason,s.DenialReason,s.[90DayLetterSentOn],s.BenefitsRecvd
	FROM [SCRA_DB_MIGRATE].[dbo].[Sample] s 
	JOIN [dbo].[Servicemember] sm ON s.ServiceMemberID = sm.ServicememberID
	) 
	SELECT DISTINCT
		 com.Id								AS CommunicationID
		,CAST(COALESCE(i.InquiryDate, 
				cte.DateOfContact,
				com.CommunicationDate)
				as DATE)					AS DateOfContact
		,com.TaskId as ComTaskId
		,(SELECT MAX([CompletionDate]) FROM (SELECT CONVERT(varchar(10),MAX(st.CompletionDate),121) as [CompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON st.TaskID = tt.ID and st.Title = 'Save all Documents' WHERE tt.ID = com.TaskID and st.[Status]<> 'rejected' GROUP BY st.CompletionDate HAVING st.CompletionDate = MAX(st.CompletionDate)) th) as TEST
		,cte.MethodOfNotification			AS MethodOfNotification
		,CAST(cte.DateDMDCSearchPerformed
			 as DATE)						AS DateDMDCSearchPerformed
		,cte.VerifyBySCRAOrMilOrders		AS VerifyBySCRAOrMilOrders
		,cte.BenefitApprovedDeniedPending	AS BenefitApprovedDeniedPending
		,b.[Status]							AS StatusCode
		,b.DenialReason						AS NotEligReason
		,b.DenialReason
		,p.ID								AS ServiceMemberID
		,p.LastName							AS ServicememberLastName
		,p.FirstName						AS ServicememberFirstname
		,p.MiddleInitial					AS ServicememberMiddleInitial
		,p.SSN								AS SocialSecurityNumber
		,bd.BenefitAppliedDate				AS DateBenefitsApplied
		,CASE 
			WHEN ISNULL(bd.BenefitAppliedDate,'') <> '' AND 
					ISNULL(COALESCE(i.InquiryDate, 
								cte.DateOfContact,
						   com.CommunicationDate),'') <> '' THEN
				CASE 
					WHEN DATEDIFF(d,COALESCE(i.InquiryDate, 
								cte.DateOfContact,
						   com.CommunicationDate),
						   bd.BenefitAppliedDate) <= 60 THEN 'True'
					ELSE ''
				END
			ELSE ''
		 END								AS BenefitsAppliedWithin60Days
		,bd.BenefitRemovedDate				AS DateBenefitsEnded
		,bd.BenefitEffectiveDate			AS [Benefits Effective (as of) Date]
		,REPLACE(REPLACE(REPLACE(note.Comment,CHAR(13)+CHAR(10),'|'),CHAR(34),''''''),CHAR(9),' ') AS Comments
		,REPLACE(REPLACE(REPLACE(note.Comment,CHAR(13)+CHAR(10),'|'),CHAR(34),''''''),CHAR(9),' ') AS AdditionalComments
		--,ct.CATEGORY_ORIGIN
		,CASE WHEN ct.SCRA_Code = 'auto' THEN 'Auto'
			  WHEN ct.SCRA_Code = 'commercial' THEN 'Commercial Loan'
			  WHEN ct.SCRA_Code = 'consumer_loan' THEN 'Consumer Loan'
			  WHEN ct.SCRA_Code = 'credit_card' THEN 'Credit Card'
			  WHEN ct.SCRA_Code = 'mortgage' THEN 'Mortgage'
			  WHEN ct.SCRA_Code = 'safe_dep_box' THEN 'Safe Deposit Box'
			  WHEN ISNULL(ct.SCRA_Code,'') = '' THEN ''
			  ELSE 'Other' END
											AS ProductType
		,ct.SUB_PRODUCT_NAME				AS SubType
		,cnt.OpenDate						AS StartDate
		,cnt.CloseDate						AS EndDate
		,p.ID
		,cust.FNumber
		,bos.Branch							AS BranchOfService
		,ad.NoticeDate						AS DateMilitaryOrdersReceived
		,cte.ActiveAccountEligible			AS ActiveAccountEligible
		,COALESCE(
			CASE 
				WHEN ISNULL(cnt.LegacyNo,'') = '' 
				THEN NULL 
				ELSE cnt.LegacyNo END,
			CASE 
				WHEN ISNULL(cnt.CardNo,'') = '' 
				THEN NULL 
				ELSE cnt.CardNo END,
			CASE 
				WHEN ISNULL(cnt.ContractNo,'') = '' 
				THEN NULL 
				ELSE cnt.ContractNo END)	AS AccountNum
		,ad.StartDate						AS ADStartDate
		,ad.EndDate							AS ADEndDate
		,p.Address1
		,p.Address2
		,p.City
		,p.[State]
		,p.Zip
		,p.Email
		,cte.BenefitsRecvd					AS BenefitsRecvd
		,bd.CurrentRate						AS InterestRateBeforeScra
		,bd.IsInterestAdjustmentCalculated	AS InterestAdjustment
		,bd.InterestRefunded				AS RefundAmount
		,bd.InterestRefundedDate			AS RefundDate
		,ld.ID								AS LetterID
		,CASE WHEN com.LetterId IS NOT NULL 
				THEN COALESCE((SELECT MAX([CompletionDate]) 
					FROM (SELECT CONVERT(varchar(10),MAX(st.CompletionDate),121) as [CompletionDate] 
						FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON st.TaskID = tt.ID and st.Title = 'Save all Documents' 
							WHERE tt.ID = com.TaskID and st.[Status]<> 'rejected' 
								GROUP BY st.CompletionDate 
									HAVING st.CompletionDate = MAX(st.CompletionDate)) th),com.CommunicationDate)
				ELSE NULL END				AS DateSent
		,CASE WHEN com.LetterId IS NOT NULL 
				THEN ld.LetterCode 
				ELSE NULL END				AS LetterCode
		,NULL								AS Returned
		,NULL								AS Account
		,CASE WHEN com.LetterId IS NOT NULL 
				THEN ld.LetterName 
				ELSE NULL END				AS LetterName 
	 FROM dbo.Person p 
		LEFT JOIN dbo.Communication com 
			ON com.PersonID = p.ID
		INNER JOIN dbo.ContactMethod cm 
			ON com.ContactMethodId = cm.ID
		LEFT JOIN dbo.Customer cust 
			ON cust.PersonID = p.ID
		LEFT JOIN dbo.Note note 
			ON note.PersonID = p.ID
		LEFT JOIN dbo.Benefit b 
			ON com.BenefitID = b.ID
		LEFT JOIN dbo.BenefitDetail bd 
			ON b.ID = bd.BenefitId
		LEFT JOIN dbo.[Contract] cnt 
			ON cnt.ID = b.ContractID
		INNER JOIN dbo.ContractType ct 
			ON cnt.ContractTypeId = ct.ID
		LEFT JOIN dbo.ActiveDuty ad 
			ON ad.PersonID = p.ID
		INNER JOIN dbo.BranchOfService bos 
			ON ad.BranchOfServiceID = bos.ID
		LEFT JOIN dbo.Letter_DATA ld 
			ON ld.ID = com.LetterId
		LEFT JOIN dbo.Inquiry i
			ON p.ID = i.ServicememberId AND i.InquiryType = 'benefit_request'
			
		LEFT JOIN CTE cte ON p.ID = cte.PersonID
		
	OUTER APPLY (SELECT CASE WHEN inq.DMDCValidationDate IS NULL THEN inq.InquiryDate ELSE inq.DMDCValidationDate END AS DMDCValidationDate 
				FROM dbo.Inquiry inq 
					INNER JOIN dbo.Task task 
						ON inq.ID  = task.InquiryID 
					WHERE inq.InquiryType = 'dmdc_check' AND task.ID = com.TaskId) dmdc
ORDER BY CAST(COALESCE(i.InquiryDate, 
				cte.DateOfContact,
				com.CommunicationDate)
				as DATE) DESC					
					
/*
EXEC [dbo].[spServicemember_Monthly_Incoming_GN_Letter_Sent_report]
*/
GO
/****** Object:  StoredProcedure [dbo].[spServiceMember_Expired_Denied_Active_Report]    Script Date: 05/22/2019 10:19:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spServiceMember_Expired_Denied_Active_Report]
WITH RECOMPILE
AS
	SET NOCOUNT ON;
--	;with CTE AS (
--	SELECT DISTINCT sm.PersonID,s.DateOfContact,s.MethodOfNotification,s.DateDMDCSearchPerformed,s.VerifyBySCRAOrMilOrders
--				,s.ActiveAccountEligible,s.BenefitApprovedDeniedPending,s.StatusCode
--				,s.NotEligReason,s.DenialReason,s.[90DayLetterSentOn],s.BenefitsRecvd,s.Returned,s.Account
--	FROM [SCRA_DB_MIGRATE].[dbo].[Sample] s 
--	JOIN [dbo].[Servicemember] sm ON s.ServiceMemberID = sm.ServicememberID
--	) 
--	SELECT DISTINCT
--		 COALESCE(cast(cte.DateOfContact as date), 
--					CASE WHEN cast(p.[Timestamp] as date) = '2019-02-15' THEN NULL ELSE cast(p.[timestamp] as date) END)
--				  							AS DateOfContact
--		,COALESCE(cte.MethodOfNotification,
--				  cm.Name)					AS MethodOfNotification
--		,CAST(cte.DateDMDCSearchPerformed 
--							as DATE)		AS DateDMDCSearchPerformed
--		,cte.VerifyBySCRAOrMilOrders		AS VerifyBySCRAOrMilOrders
--		,ad.NoticeDate						AS DateMilitaryOrdersReceived
--		,COALESCE(cte.BenefitApprovedDeniedPending,
--					CASE WHEN ISNULL(b.DenialReason	,'') <> '' THEN 'Denied' 
--						ELSE UPPER(SUBSTRING(b.[Status],1,1))+SUBSTRING(b.[Status],2,LEN(b.[Status])-1) END)
--											AS BenefitApprovedDeniedPending
--		,COALESCE(cte.StatusCode, 
--					CASE WHEN ISNULL(b.DenialReason	,'') <> '' THEN 'Not Eligible' 
--					ELSE 
--						CASE WHEN b.[Status] IN ('applying','applied','removing') THEN 'Active Duty' ELSE NULL END END)
--											AS StatusCode
--		,b.DenialReason						AS NotEligReason
--		,b.DenialReason
--		,p.ID								AS ServiceMemberID
--		,p.LastName							AS ServicememberLastName
--		,p.FirstName						AS ServicememberFirstname
--		,p.MiddleInitial					AS ServicememberMiddleInitial
--		,p.DOB								AS DOB
--		,cust.FNumber
--		,p.SSN								AS SocialSecurityNumber
--		,bos.Branch							AS BranchOfService
--		,ad.StartDate						AS ADStartDate
--		,ad.EndDate							AS ADEndDate
--		,bd.BenefitAppliedDate				AS DateBenefitsApplied
--		,bd.BenefitRemovedDate				AS DateBenefitsEnded
--		,bd.BenefitEffectiveDate			AS BenefitsEffectiveDate
--		,ct.CATEGORY_ORIGIN					AS ProductType
--		,ct.SUB_PRODUCT_NAME				AS SubType
--		,COALESCE(
--			CASE 
--				WHEN ISNULL(cnt.LegacyNo,'') = '' 
--				THEN NULL 
--				ELSE cnt.LegacyNo END,
--			CASE 
--				WHEN ISNULL(cnt.CardNo,'') = '' 
--				THEN NULL 
--				ELSE cnt.CardNo END,
--			CASE 
--				WHEN ISNULL(cnt.ContractNo,'') = '' 
--				THEN NULL 
--				ELSE cnt.ContractNo END)	AS AccountNum
--		,cnt.OpenDate						AS StartDate
--		,cnt.CloseDate						AS EndDate
--		,cte.ActiveAccountEligible			AS ActiveAccountEligible
--		,p.Address1
--		,p.Address2
--		,p.City
--		,p.[State]
--		,p.Zip
--		,p.Email
--		,cte.BenefitsRecvd					AS BenefitsRecvd
--		,bd.CurrentRate						AS [Interest Rate before SCRA]
--		,bd.IsInterestAdjustmentCalculated	AS [Interest Adjustment]
--		,bd.PromotionEndDate				AS [Promo Rate End Date] 
--		,bd.InterestRefunded				AS RefundAmount
--		,bd.InterestRefundedDate			AS RefundDate
--		,REPLACE(REPLACE(REPLACE(note.Comment,CHAR(13)+CHAR(10),'|'),CHAR(34),''''''),CHAR(9),' ') AS Comments
--		,REPLACE(REPLACE(REPLACE(note.Comment,CHAR(13)+CHAR(10),'|'),CHAR(34),''''''),CHAR(9),' ') AS AdditionalComments
--		,com.ID								AS LetterID
--		,com.CommunicationDate				AS DateSent
--		,com.LetterId						AS LetterCode
--		,cte.Returned						AS Returned
--		,cte.Account						AS Account
--		,ld.LetterName						AS LetterName
--	 FROM dbo.Person p 
--		LEFT JOIN dbo.Communication com 
--			ON p.ID = com.PersonID
--		LEFT JOIN dbo.Inquiry r
--			ON p.ID = COALESCE(r.ServicememberId,r.PersonInquiringId)
--		LEFT JOIN dbo.ContactMethod cm 
--			ON r.ContactMethodId = cm.ID
--		LEFT JOIN dbo.Customer cust 
--			ON p.ID = cust.PersonID
--		LEFT JOIN dbo.Note note 
--			ON p.ID = note.PersonID
--		LEFT JOIN dbo.Benefit b 
--			ON p.ID = b.PersonID --AND com.BenefitID = b.ID
--		LEFT JOIN dbo.BenefitDetail bd 
--			ON b.ID = bd.BenefitId
--		LEFT JOIN dbo.[Contract] cnt 
--			ON b.ContractID = cnt.ID AND cnt.IsDeleted = 0 OR 
--				cnt.PersonID in (Select pp.ID As PersonId
--							from Person pp
--							where pp.ID  in (Select ToID from PersonToPersonLink where FromID = p.Id) OR pp.ID  in (Select FromID from PersonToPersonLink where ToID = p.Id) OR pp.ID = p.Id
--						)
--		LEFT JOIN dbo.ContractType ct 
--			ON cnt.ContractTypeId = ct.ID
--		LEFT JOIN dbo.ActiveDuty ad 
--			ON p.ID = ad.PersonID
--		INNER JOIN dbo.BranchOfService bos 
--			ON bos.ID = ad.BranchOfServiceID
--		LEFT JOIN dbo.Letter_DATA ld 
--			ON com.LetterId = ld.ID
			
--		LEFT JOIN CTE cte ON p.ID = cte.PersonID			
			
--		OUTER APPLY (SELECT CASE WHEN inq.DMDCValidationDate IS NULL THEN inq.InquiryDate ELSE inq.DMDCValidationDate END AS DMDCValidationDate 
--					FROM dbo.Inquiry inq 
--						INNER JOIN dbo.Task task 
--							ON inq.ID  = task.InquiryID 
--						WHERE inq.InquiryType = 'dmdc_check' AND task.ID = com.TaskId) dmdc

--ORDER BY COALESCE(cast(cte.DateOfContact as date), 
--					CASE WHEN cast(p.[Timestamp] as date) = '2019-02-15' THEN NULL ELSE cast(p.[timestamp] as date) END) DESC			

--;with CTE AS (
--	SELECT DISTINCT sm.PersonID,s.DateOfContact,s.MethodOfNotification,s.DateDMDCSearchPerformed,s.VerifyBySCRAOrMilOrders
--				,s.ActiveAccountEligible,s.BenefitApprovedDeniedPending,s.StatusCode
--				,s.NotEligReason,s.DenialReason,s.[90DayLetterSentOn],s.BenefitsRecvd,s.Returned,s.Account
--	FROM [SCRA_DB_MIGRATE].[dbo].[Sample] s 
--	JOIN [dbo].[Servicemember] sm ON s.ServiceMemberID = sm.ServicememberID
--	) 
--	SELECT DISTINCT
--		 COALESCE(cast(cte.DateOfContact as date), 
--					CASE WHEN cast(p.[Timestamp] as date) = '2019-02-15' THEN NULL ELSE cast(p.[timestamp] as date) END)
--				  							AS DateOfContact
--		,COALESCE(cte.MethodOfNotification,
--				  cm.Name)					AS MethodOfNotification
--		,CAST(cte.DateDMDCSearchPerformed 
--							as DATE)		AS DateDMDCSearchPerformed
--		,cte.VerifyBySCRAOrMilOrders		AS VerifyBySCRAOrMilOrders
--		,ad.NoticeDate						AS DateMilitaryOrdersReceived
--		,COALESCE(cte.BenefitApprovedDeniedPending,
--					CASE WHEN ISNULL(b.DenialReason	,'') <> '' THEN 'Denied' 
--						ELSE CASE WHEN ISNULL(b.[Status],'') <> '' THEN UPPER(SUBSTRING(b.[Status],1,1))+SUBSTRING(b.[Status],2,LEN(b.[Status])-1)
--							ELSE '' END END)
--											AS BenefitApprovedDeniedPending
--		,COALESCE(cte.StatusCode, 
--					CASE WHEN ISNULL(b.DenialReason	,'') <> '' THEN 'Not Eligible' 
--					ELSE 
--						CASE WHEN b.[Status] IN ('applying','applied','removing') THEN 'Active Duty' ELSE NULL END END)
--											AS StatusCode
--		,b.DenialReason						AS NotEligReason
--		,b.DenialReason
--		,p.ID								AS ServiceMemberID
--		,p.LastName							AS ServicememberLastName
--		,p.FirstName						AS ServicememberFirstname
--		,p.MiddleInitial					AS ServicememberMiddleInitial
--		,p.DOB								AS DOB
--		,cust.FNumber
--		,p.SSN								AS SocialSecurityNumber
--		,bos.Branch							AS BranchOfService
--		,ad.StartDate						AS ADStartDate
--		,ad.EndDate							AS ADEndDate
--		,bd.BenefitAppliedDate				AS DateBenefitsApplied
--		,bd.ExpectedRemovalDate				AS ExpectedRemovalDate
--		,bd.BenefitRemovedDate				AS DateBenefitsEnded
--		,bd.BenefitEffectiveDate			AS BenefitsEffectiveDate
--		--,ct.CATEGORY_ORIGIN
--		,CASE WHEN ct.SCRA_Code = 'auto' THEN 'Auto'
--			  WHEN ct.SCRA_Code = 'commercial' THEN 'Commercial Loan'
--			  WHEN ct.SCRA_Code = 'consumer_loan' THEN 'Consumer Loan'
--			  WHEN ct.SCRA_Code = 'credit_card' THEN 'Credit Card'
--			  WHEN ct.SCRA_Code = 'mortgage' THEN 'Mortgage'
--			  WHEN ct.SCRA_Code = 'safe_dep_box' THEN 'Safe Deposit Box'
--			  WHEN ISNULL(ct.SCRA_Code,'') = '' THEN ''
--			  ELSE 'Other' END
--											AS ProductType
--		,ct.SUB_PRODUCT_NAME				AS SubType
--		,COALESCE(
--			CASE 
--				WHEN ISNULL(cnt.LegacyNo,'') = '' 
--				THEN NULL 
--				ELSE cnt.LegacyNo END,
--			CASE 
--				WHEN ISNULL(cnt.CardNo,'') = '' 
--				THEN NULL 
--				ELSE cnt.CardNo END,
--			CASE 
--				WHEN ISNULL(cnt.ContractNo,'') = '' 
--				THEN NULL 
--				ELSE cnt.ContractNo END)	AS AccountNum
--		,cnt.OpenDate						AS StartDate
--		,cnt.CloseDate						AS EndDate
--		,COALESCE(cte.ActiveAccountEligible,
--			CASE WHEN ISNULL(b.DenialReason	,'') <> '' 
--					THEN 0 
--					ELSE 
--						CASE WHEN b.[Status] IN ('applying','applied','removing') 
--							THEN 1 ELSE 0 END END)
--											AS ActiveAccountEligible
--		,p.Address1
--		,p.Address2
--		,p.City
--		,p.[State]
--		,p.Zip
--		,p.Email
--		,COALESCE(cte.BenefitsRecvd,
--			CASE WHEN ISNULL(b.DenialReason	,'') <> '' 
--					THEN 0 
--					ELSE 
--						CASE WHEN b.[Status] IN ('applying','applied','removing') 
--							THEN 1 ELSE 0 END END)
--											AS BenefitsRecvd
--		,bd.CurrentRate						AS [Interest Rate before SCRA]
--		,bd.IsInterestAdjustmentCalculated	AS [Interest Adjustment]
--		,bd.PromotionEndDate				AS [Promo Rate End Date] 
--		,bd.InterestRefunded				AS RefundAmount
--		,bd.InterestRefundedDate			AS RefundDate
--		,REPLACE(REPLACE(REPLACE(note.Comment,CHAR(13)+CHAR(10),'|'),CHAR(34),''''''),CHAR(9),' ') AS Comments
--		,REPLACE(REPLACE(REPLACE(note.Comment,CHAR(13)+CHAR(10),'|'),CHAR(34),''''''),CHAR(9),' ') AS AdditionalComments
--		,com.ID								AS LetterID
--		,com.CommunicationDate				AS DateSent
--		,com.LetterId						AS LetterCode
--		,cte.Returned						AS Returned
--		,RIGHT(COALESCE(cte.Account,CASE WHEN ISNULL(cnt.LegacyNo,'') = '' THEN NULL ELSE cnt.LegacyNo END,CASE WHEN ISNULL(cnt.CardNo,'') = '' THEN NULL ELSE cnt.CardNo END),4)						
--											AS Account
--		,ld.LetterName						AS LetterName
--	 FROM dbo.Person p 
		
--		outer apply( Select distinct ID,CommunicationDate,LetterId, TaskId  from dbo.Communication where PersonID in (Select pp.ID As PersonId from Person pp 
--						where pp.ID in (Select pl.ToID from PersonToPersonLink pl where pl.FromID = p.ID) 
--							OR pp.ID  in (Select pl.FromID from PersonToPersonLink pl where pl.ToID = p.ID) OR pp.ID = p.ID)) com
		
--		outer apply (Select distinct  ContactMethodID from dbo.Inquiry where COALESCE(ServicememberId,PersonInquiringId) in (Select pp.ID As PersonId from Person pp 
--						where pp.ID in (Select pl.ToID from PersonToPersonLink pl where pl.FromID = p.ID) 
--							OR pp.ID  in (Select pl.FromID from PersonToPersonLink pl where pl.ToID = p.ID) OR pp.ID = p.ID)) as r
--		LEFT JOIN dbo.ContactMethod cm 
--			ON r.ContactMethodId = cm.ID
			
--		outer apply(Select distinct FNumber from dbo.Customer where PersonID=p.ID and PersonID in (Select pp.ID As PersonId from Person pp 
--						where pp.ID in (Select pl.ToID from PersonToPersonLink pl where pl.FromID = p.ID) 
--							OR pp.ID  in (Select pl.FromID from PersonToPersonLink pl where pl.ToID = p.ID) OR pp.ID = p.ID)) cust
							
--		outer apply(select distinct Comment from dbo.Note where PersonID in (Select pp.ID As PersonId from Person pp 
--						where pp.ID in (Select pl.ToID from PersonToPersonLink pl where pl.FromID = p.ID) 
--							OR pp.ID  in (Select pl.FromID from PersonToPersonLink pl where pl.ToID = p.ID) OR pp.ID = p.ID)) note
		
--		outer apply (select * from dbo.Benefit where PersonID in (Select pp.ID As PersonId from Person pp 
--						where pp.ID in (Select pl.ToID from PersonToPersonLink pl where pl.FromID = p.ID) 
--							OR pp.ID  in (Select pl.FromID from PersonToPersonLink pl where pl.ToID = p.ID) OR pp.ID = p.ID)) b
--		LEFT JOIN dbo.BenefitDetail bd 
--			ON b.ID = bd.BenefitId
		
--		outer apply (select * from dbo.[Contract] where b.ContractID = ID AND IsDeleted = 0 AND PersonID in (Select pp.ID As PersonId from Person pp 
--						where pp.ID in (Select pl.ToID from PersonToPersonLink pl where pl.FromID = p.ID) 
--							OR pp.ID  in (Select pl.FromID from PersonToPersonLink pl where pl.ToID = p.ID) OR pp.ID = p.ID)) cnt
--		LEFT JOIN dbo.ContractType ct 
--			ON cnt.ContractTypeId = ct.ID
		
--		outer apply (Select * from dbo.ActiveDuty where PersonID in (Select pp.ID As PersonId from Person pp 
--						where pp.ID in (Select pl.ToID from PersonToPersonLink pl where pl.FromID = p.ID) 
--							OR pp.ID  in (Select pl.FromID from PersonToPersonLink pl where pl.ToID = p.ID) OR pp.ID = p.ID)) ad
--		INNER JOIN dbo.BranchOfService bos 
--			ON bos.ID = ad.BranchOfServiceID
			
--		LEFT JOIN dbo.Letter_DATA ld 
--			ON com.LetterId = ld.ID
			
--		LEFT JOIN CTE cte ON p.ID = cte.PersonID			
			
--		OUTER APPLY (SELECT CASE WHEN inq.DMDCValidationDate IS NULL THEN inq.InquiryDate ELSE inq.DMDCValidationDate END AS DMDCValidationDate 
--					FROM dbo.Inquiry inq 
--						INNER JOIN dbo.Task task 
--							ON inq.ID  = task.InquiryID 
--						WHERE inq.InquiryType = 'dmdc_check' AND task.ID = com.TaskId) dmdc
						
--ORDER BY COALESCE(cast(cte.DateOfContact as date), 
--					CASE WHEN cast(p.[Timestamp] as date) = '2019-02-15' THEN NULL ELSE cast(p.[timestamp] as date) END) DESC			

--;with CTE AS (
--	SELECT DISTINCT sm.PersonID,s.DateOfContact,s.MethodOfNotification,s.DateDMDCSearchPerformed,s.VerifyBySCRAOrMilOrders
--				,s.ActiveAccountEligible,s.BenefitApprovedDeniedPending,s.StatusCode
--				,s.NotEligReason,s.DenialReason,s.[90DayLetterSentOn],s.BenefitsRecvd,s.Returned,s.Account
--	FROM [SCRA_DB_MIGRATE].[dbo].[Sample] s 
--	JOIN [dbo].[Servicemember] sm ON s.ServiceMemberID = sm.ServicememberID
--	) 
--	SELECT DISTINCT
--		 COALESCE(cast(cte.DateOfContact as date), 
--					CASE WHEN cast(p.[Timestamp] as date) = '2019-02-15' THEN NULL ELSE cast(p.[timestamp] as date) END)
--				  							AS DateOfContact
--		,COALESCE(cte.MethodOfNotification,
--				  cm.Name)					AS MethodOfNotification
--		,CAST(cte.DateDMDCSearchPerformed 
--							as DATE)		AS DateDMDCSearchPerformed
--		,cte.VerifyBySCRAOrMilOrders		AS VerifyBySCRAOrMilOrders
--		,ad.NoticeDate						AS DateMilitaryOrdersReceived
--		--,b.[Status]
--		,COALESCE(CASE WHEN ISNULL(b.DenialReason	,'') <> '' THEN 'Denied' 
--						ELSE CASE WHEN ISNULL(b.[Status],'') <> '' THEN UPPER(SUBSTRING(b.[Status],1,1))+SUBSTRING(b.[Status],2,LEN(b.[Status])-1)
--							ELSE NULL END END,
--							cte.BenefitApprovedDeniedPending)
--											AS BenefitApprovedDeniedPending
--		,COALESCE(					CASE WHEN ISNULL(b.DenialReason	,'') <> '' THEN 'Not Eligible' 
--					ELSE 
--						CASE WHEN b.[Status] IN ('applying','applied','removing') THEN 'Active Duty' ELSE NULL END END,
--						cte.StatusCode)
--											AS StatusCode
--		,b.DenialReason						AS NotEligReason
--		,b.DenialReason
--		,p.ID								AS ServiceMemberID
--		,p.LastName							AS ServicememberLastName
--		,p.FirstName						AS ServicememberFirstname
--		,p.MiddleInitial					AS ServicememberMiddleInitial
--		,p.DOB								AS DOB
--		,cust.FNumber
--		,p.SSN								AS SocialSecurityNumber
--		,bos.Branch							AS BranchOfService
--		,ad.StartDate						AS ADStartDate
--		,ad.EndDate							AS ADEndDate
--		,bd.BenefitAppliedDate				AS DateBenefitsApplied
--		,bd.ExpectedRemovalDate				AS ExpectedRemovalDate
--		,bd.BenefitRemovedDate				AS DateBenefitsEnded
--		,bd.BenefitEffectiveDate			AS BenefitsEffectiveDate
--		,CASE WHEN ct.SCRA_Code = 'auto' THEN 'Auto'
--			  WHEN ct.SCRA_Code = 'commercial' THEN 'Commercial Loan'
--			  WHEN ct.SCRA_Code = 'consumer_loan' THEN 'Consumer Loan'
--			  WHEN ct.SCRA_Code = 'credit_card' THEN 'Credit Card'
--			  WHEN ct.SCRA_Code = 'mortgage' THEN 'Mortgage'
--			  WHEN ct.SCRA_Code = 'safe_dep_box' THEN 'Safe Deposit Box'
--			  WHEN ISNULL(ct.SCRA_Code,'') = '' THEN ''
--			  ELSE 'Other' END
--											AS ProductType
--		,ct.SUB_PRODUCT_NAME				AS SubType
--		,COALESCE(
--			CASE 
--				WHEN ISNULL(cnt.LegacyNo,'') = '' 
--				THEN NULL 
--				ELSE cnt.LegacyNo END,
--			CASE 
--				WHEN ISNULL(cnt.CardNo,'') = '' 
--				THEN NULL 
--				ELSE cnt.CardNo END,
--			CASE 
--				WHEN ISNULL(cnt.ContractNo,'') = '' 
--				THEN NULL 
--				ELSE cnt.ContractNo END)	AS AccountNum
--		,cnt.OpenDate						AS StartDate
--		,cnt.CloseDate						AS EndDate
--		,COALESCE(cte.ActiveAccountEligible,
--			CASE WHEN ISNULL(b.DenialReason	,'') <> '' 
--					THEN 0 
--					ELSE 
--						CASE WHEN b.[Status] IN ('applying','applied','removing') 
--							THEN 1 ELSE 0 END END)
--											AS ActiveAccountEligible
--		,p.Address1
--		,p.Address2
--		,p.City
--		,p.[State]
--		,p.Zip
--		,p.Email
--		,COALESCE(cte.BenefitsRecvd,
--			CASE WHEN ISNULL(b.DenialReason	,'') <> '' 
--					THEN 0 
--					ELSE 
--						CASE WHEN b.[Status] IN ('applying','applied','removing') 
--							THEN 1 ELSE 0 END END)
--											AS BenefitsRecvd
--		,bd.CurrentRate						AS [Interest Rate before SCRA]
--		,bd.IsInterestAdjustmentCalculated	AS [Interest Adjustment]
--		,bd.PromotionEndDate				AS [Promo Rate End Date] 
--		,bd.InterestRefunded				AS RefundAmount
--		,bd.InterestRefundedDate			AS RefundDate
--		,REPLACE(REPLACE(REPLACE(note.Comment,CHAR(13)+CHAR(10),'|'),CHAR(34),''''''),CHAR(9),' ') AS Comments
--		,REPLACE(REPLACE(REPLACE(note.Comment,CHAR(13)+CHAR(10),'|'),CHAR(34),''''''),CHAR(9),' ') AS AdditionalComments
--		,com.ID								AS LetterID
--		,com.CommunicationDate				AS DateSent
--		,com.LetterId						AS LetterCode
--		,cte.Returned						AS Returned
--		,RIGHT(COALESCE(cte.Account,CASE WHEN ISNULL(cnt.LegacyNo,'') = '' THEN NULL ELSE cnt.LegacyNo END,CASE WHEN ISNULL(cnt.CardNo,'') = '' THEN NULL ELSE cnt.CardNo END),4)						
--											AS Account
--		,ld.LetterName						AS LetterName
--	 FROM dbo.Person p 
		
--		outer apply( Select distinct ID,CommunicationDate,LetterId, TaskId,PersonId  from dbo.Communication where PersonID in (Select pp.ID As PersonId from Person pp 
--						where ((pp.ID in (Select pl.ToID from PersonToPersonLink pl where pl.FromID = p.ID) 
--								OR pp.ID  in (Select pl.FromID from PersonToPersonLink pl where pl.ToID = p.ID)
--								OR pp.ID = p.ID))
--								OR pp.ID IN (Select ServicememberId from dbo.Inquiry i WHERE i.ServicememberId = p.ID ))) com
		
--		outer apply (Select distinct  ContactMethodID from dbo.Inquiry where COALESCE(ServicememberId,PersonInquiringId) in (Select pp.ID As PersonId from Person pp 
--						where ((pp.ID in (Select pl.ToID from PersonToPersonLink pl where pl.FromID = p.ID) 
--								OR pp.ID  in (Select pl.FromID from PersonToPersonLink pl where pl.ToID = p.ID)
--								OR pp.ID = p.ID))
--								OR pp.ID IN (Select ServicememberId from dbo.Inquiry i WHERE i.ServicememberId = p.ID ))) r
--		LEFT JOIN dbo.ContactMethod cm 
--			ON r.ContactMethodId = cm.ID
			
--		outer apply(Select distinct FNumber from dbo.Customer where PersonID=p.ID and PersonID in (Select pp.ID As PersonId from Person pp 
--						where ((pp.ID in (Select pl.ToID from PersonToPersonLink pl where pl.FromID = p.ID) 
--								OR pp.ID  in (Select pl.FromID from PersonToPersonLink pl where pl.ToID = p.ID)
--								OR pp.ID = p.ID))
--								OR pp.ID IN (Select ServicememberId from dbo.Inquiry i WHERE i.ServicememberId = p.ID ))) cust
							
--		outer apply(select distinct Comment from dbo.Note where PersonID in (Select pp.ID As PersonId from Person pp 
--						where ((pp.ID in (Select pl.ToID from PersonToPersonLink pl where pl.FromID = p.ID) 
--								OR pp.ID  in (Select pl.FromID from PersonToPersonLink pl where pl.ToID = p.ID)
--								OR pp.ID = p.ID))
--								OR pp.ID IN (Select ServicememberId from dbo.Inquiry i WHERE i.ServicememberId = p.ID ))) note
		
--		outer apply (select * from dbo.Benefit bb where PersonID in (Select pp.ID As PersonId from Person pp 
--						where ((pp.ID in (Select pl.ToID from PersonToPersonLink pl where pl.FromID = p.ID) 
--								OR pp.ID  in (Select pl.FromID from PersonToPersonLink pl where pl.ToID = p.ID)
--								OR pp.ID = p.ID))
--								OR pp.ID IN (Select ServicememberId from dbo.Inquiry i WHERE i.ServicememberId = p.ID ))
--								AND ContractID = (SELECT ID FROM dbo.[Contract] WHERE PersonID = p.ID and ID = bb.ContractID)
--								AND ActiveDutyID IN (SELECT ID FROM ActiveDuty WHERE PersonID = p.ID)) b
--		 LEFT JOIN dbo.BenefitDetail bd 
--			ON b.ID = bd.BenefitId
		
--		outer apply (select * from dbo.[Contract] where b.ContractID = ID AND IsDeleted = 0 AND PersonID in (Select pp.ID As PersonId from Person pp 
--						where ((pp.ID in (Select pl.ToID from PersonToPersonLink pl where pl.FromID = p.ID) 
--								OR pp.ID  in (Select pl.FromID from PersonToPersonLink pl where pl.ToID = p.ID)
--								OR pp.ID = p.ID))
--								OR pp.ID IN (Select ServicememberId from dbo.Inquiry i WHERE i.ServicememberId = p.ID ))
--								AND ID IN (SELECT ContractID FROM dbo.Benefit WHERE PersonID = p.ID and ID = b.ID)) cnt
--		LEFT JOIN dbo.ContractType ct 
--			ON cnt.ContractTypeId = ct.ID
		
--		outer apply (Select * from dbo.ActiveDuty where PersonID in (Select pp.ID As PersonId from Person pp 
--						where ((pp.ID in (Select pl.ToID from PersonToPersonLink pl where pl.FromID = p.ID) 
--								OR pp.ID  in (Select pl.FromID from PersonToPersonLink pl where pl.ToID = p.ID)
--								OR pp.ID = p.ID))
--								OR pp.ID IN (Select ServicememberId from dbo.Inquiry i WHERE i.ServicememberId = p.ID ))) ad
--		INNER JOIN dbo.BranchOfService bos 
--			ON bos.ID = ad.BranchOfServiceID
			
--		LEFT JOIN dbo.Letter_DATA ld 
--			ON com.LetterId = ld.ID AND com.PersonID = p.ID
			
--		LEFT JOIN CTE cte ON p.ID = cte.PersonID			
			
--		OUTER APPLY (SELECT CASE WHEN inq.DMDCValidationDate IS NULL THEN inq.InquiryDate ELSE inq.DMDCValidationDate END AS DMDCValidationDate 
--					FROM dbo.Inquiry inq 
--						INNER JOIN dbo.Task task 
--							ON inq.ID  = task.InquiryID 
--						WHERE inq.InquiryType = 'dmdc_check' AND task.ID = com.TaskId) dmdc
						
--ORDER BY COALESCE(cast(cte.DateOfContact as date), 
--					CASE WHEN cast(p.[Timestamp] as date) = '2019-02-15' THEN NULL ELSE cast(p.[timestamp] as date) END) DESC

;with CTE AS (
	SELECT DISTINCT sm.PersonID,s.DateOfContact,s.MethodOfNotification,s.DateDMDCSearchPerformed,s.VerifyBySCRAOrMilOrders
				,s.ActiveAccountEligible,s.BenefitApprovedDeniedPending,s.StatusCode
				,s.NotEligReason,s.DenialReason,s.[90DayLetterSentOn],s.BenefitsRecvd,s.Returned,s.Account
	FROM [SCRA_DB_MIGRATE].[dbo].[Sample] s 
	JOIN [dbo].[Servicemember] sm ON s.ServiceMemberID = sm.ServicememberID
	) 
	SELECT DISTINCT
		 COALESCE(cast(cte.DateOfContact as date), 
					CASE WHEN cast(p.[Timestamp] as date) = '2019-02-15' THEN NULL ELSE cast(p.[timestamp] as date) END)
				  							AS DateOfContact
		,COALESCE(cte.MethodOfNotification,
				  cm.Name)					AS MethodOfNotification
		,CAST(cte.DateDMDCSearchPerformed 
							as DATE)		AS DateDMDCSearchPerformed
		,cte.VerifyBySCRAOrMilOrders		AS VerifyBySCRAOrMilOrders
		,ad.NoticeDate						AS DateMilitaryOrdersReceived
		--,b.[Status]
		,COALESCE(CASE WHEN ISNULL(b.DenialReason	,'') <> '' THEN 'Denied' 
						ELSE CASE WHEN ISNULL(b.[Status],'') <> '' THEN UPPER(SUBSTRING(b.[Status],1,1))+SUBSTRING(b.[Status],2,LEN(b.[Status])-1)
							ELSE NULL END END,
							cte.BenefitApprovedDeniedPending)
											AS BenefitApprovedDeniedPending
		,COALESCE(					CASE WHEN ISNULL(b.DenialReason	,'') <> '' THEN 'Not Eligible' 
					ELSE 
						CASE WHEN b.[Status] IN ('applying','applied','removing') THEN 'Active Duty' ELSE NULL END END,
						cte.StatusCode)
											AS StatusCode
		,b.DenialReason						AS NotEligReason
		,b.DenialReason
		,p.ID								AS ServiceMemberID
		,p.LastName							AS ServicememberLastName
		,p.FirstName						AS ServicememberFirstname
		,p.MiddleInitial					AS ServicememberMiddleInitial
		,p.DOB								AS DOB
		,cust.FNumber
		,p.SSN								AS SocialSecurityNumber
		,bos.Branch							AS BranchOfService
		,ad.StartDate						AS ADStartDate
		,ad.EndDate							AS ADEndDate
		,bd.BenefitAppliedDate				AS DateBenefitsApplied
		,bd.ExpectedRemovalDate				AS ExpectedRemovalDate
		,bd.BenefitRemovedDate				AS DateBenefitsEnded
		,bd.BenefitEffectiveDate			AS BenefitsEffectiveDate
		,CASE WHEN ct.SCRA_Code = 'auto' THEN 'Auto'
			  WHEN ct.SCRA_Code = 'commercial' THEN 'Commercial Loan'
			  WHEN ct.SCRA_Code = 'consumer_loan' THEN 'Consumer Loan'
			  WHEN ct.SCRA_Code = 'credit_card' THEN 'Credit Card'
			  WHEN ct.SCRA_Code = 'mortgage' THEN 'Mortgage'
			  WHEN ct.SCRA_Code = 'safe_dep_box' THEN 'Safe Deposit Box'
			  WHEN ISNULL(ct.SCRA_Code,'') = '' THEN ''
			  ELSE 'Other' END
											AS ProductType
		,ct.SUB_PRODUCT_NAME				AS SubType
		,COALESCE(
			CASE 
				WHEN ISNULL(cnt.LegacyNo,'') = '' 
				THEN NULL 
				ELSE cnt.LegacyNo END,
			CASE 
				WHEN ISNULL(cnt.CardNo,'') = '' 
				THEN NULL 
				ELSE cnt.CardNo END,
			CASE 
				WHEN ISNULL(cnt.ContractNo,'') = '' 
				THEN NULL 
				ELSE cnt.ContractNo END)	AS AccountNum
		,cnt.OpenDate						AS StartDate
		,cnt.CloseDate						AS EndDate
		,COALESCE(cte.ActiveAccountEligible,
			CASE WHEN ISNULL(b.DenialReason	,'') <> '' 
					THEN 0 
					ELSE 
						CASE WHEN b.[Status] IN ('applying','applied','removing') 
							THEN 1 ELSE 0 END END)
											AS ActiveAccountEligible
		,p.Address1
		,p.Address2
		,p.City
		,p.[State]
		,p.Zip
		,p.Email
		,COALESCE(cte.BenefitsRecvd,
			CASE WHEN ISNULL(b.DenialReason	,'') <> '' 
					THEN 0 
					ELSE 
						CASE WHEN b.[Status] IN ('applying','applied','removing') 
							THEN 1 ELSE 0 END END)
											AS BenefitsRecvd
		,bd.CurrentRate						AS [Interest Rate before SCRA]
		,bd.IsInterestAdjustmentCalculated	AS [Interest Adjustment]
		,bd.PromotionEndDate				AS [Promo Rate End Date] 
		,bd.InterestRefunded				AS RefundAmount
		,bd.InterestRefundedDate			AS RefundDate
		,REPLACE(REPLACE(REPLACE(note.Comment,CHAR(13)+CHAR(10),'|'),CHAR(34),''''''),CHAR(9),' ') AS Comments
		,REPLACE(REPLACE(REPLACE(note.Comment,CHAR(13)+CHAR(10),'|'),CHAR(34),''''''),CHAR(9),' ') AS AdditionalComments
		,com.ID								AS LetterID
		,com.CommunicationDate				AS DateSent
		,com.LetterId						AS LetterCode
		,cte.Returned						AS Returned
		,RIGHT(COALESCE(cte.Account,CASE WHEN ISNULL(cnt.LegacyNo,'') = '' THEN NULL ELSE cnt.LegacyNo END,CASE WHEN ISNULL(cnt.CardNo,'') = '' THEN NULL ELSE cnt.CardNo END),4)						
											AS Account
		,ld.LetterName						AS LetterName
	 FROM dbo.Person p 
		
		outer apply(Select distinct FNumber from dbo.Customer where PersonID=p.ID and PersonID in (Select pp.ID As PersonId from Person pp 
						where ( pp.ID = p.ID OR pp.ID IN (Select ServicememberId from dbo.Inquiry i WHERE i.ServicememberId = p.ID )))) cust
						
		outer apply( Select distinct ID,CommunicationDate,LetterId,TaskId,PersonId,BenefitID from dbo.Communication where PersonID in (Select pp.ID As PersonId from Person pp 
							where ( pp.ID = p.ID OR pp.ID IN (Select ServicememberId from dbo.Inquiry i WHERE i.ServicememberId = p.ID )))) com
							
		outer apply (Select distinct  ContactMethodID from dbo.Inquiry where COALESCE(ServicememberId,PersonInquiringId) in (Select pp.ID As PersonId from Person pp 
							where ( pp.ID = p.ID OR pp.ID IN (Select ServicememberId from dbo.Inquiry i WHERE i.ServicememberId = p.ID )))) r
			LEFT JOIN dbo.ContactMethod cm 
				ON r.ContactMethodId = cm.ID
				
		outer apply (Select * from dbo.ActiveDuty a where a.PersonID in (Select pp.ID As PersonId from Person pp 
							where ( pp.ID = p.ID OR pp.ID IN (Select ServicememberId from dbo.Inquiry i WHERE i.ServicememberId = p.ID )))) ad
			INNER JOIN dbo.BranchOfService bos 
				ON bos.ID = ad.BranchOfServiceID
				
		outer apply (select * from dbo.Benefit bb where bb.PersonID in (Select pp.ID As PersonId from Person pp 
							where ( pp.ID = p.ID OR pp.ID IN (Select ServicememberId from dbo.Inquiry i WHERE i.ServicememberId = p.ID ))
									AND bb.ContractID IN (SELECT ID FROM dbo.[Contract] WHERE PersonID = p.ID and ID = bb.ContractID)
									AND bb.ActiveDutyID IN (SELECT ID FROM ActiveDuty WHERE PersonID = p.ID AND ID = ad.ID) )) b
			 LEFT JOIN dbo.BenefitDetail bd 
				ON b.ID = bd.BenefitId
				
		outer apply (select * from dbo.[Contract] c where b.ContractID = c.ID AND c.IsDeleted = 0 AND c.PersonID in (Select pp.ID As PersonId from Person pp 
							where ( pp.ID = p.ID OR pp.ID IN (Select ServicememberId from dbo.Inquiry i WHERE i.ServicememberId = p.ID ))
							AND c.ID = b.ContractID)) cnt
			LEFT JOIN dbo.ContractType ct 
				ON cnt.ContractTypeId = ct.ID	
				
		outer apply(select distinct Comment from dbo.Note where PersonID in (Select pp.ID As PersonId from Person pp 
							where ( pp.ID = p.ID OR pp.ID IN (Select ServicememberId from dbo.Inquiry i WHERE i.ServicememberId = p.ID )))) note					
				
		LEFT JOIN CTE cte on p.ID = cte.PersonID									

		LEFT JOIN dbo.Letter_DATA ld 
				ON com.LetterId = ld.ID AND com.PersonID = p.ID
						
ORDER BY COALESCE(cast(cte.DateOfContact as date), 
					CASE WHEN cast(p.[Timestamp] as date) = '2019-02-15' THEN NULL ELSE cast(p.[timestamp] as date) END) DESC

/*
EXEC [dbo].[spServiceMember_Expired_Denied_Active_Report]
*/

--PRINT char(34) + char(9) + ''''''
GO
/****** Object:  StoredProcedure [dbo].[spWeeklyReport_Load]    Script Date: 05/22/2019 10:19:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spWeeklyReport_Load]
	@ReportDate date
	
AS
BEGIN

	SET NOCOUNT ON;
	
	DECLARE @Interval varchar(24)
	SET @Interval = CONVERT(varchar(10),(DATEADD(wk,datediff(wk,0,dateadd(wk,0,@ReportDate)),0)),101) + ' - ' + CONVERT(varchar(10),(DATEADD(wk,datediff(wk,0,dateadd(wk,0,@ReportDate)),6)),101)
	PRINT @Interval

;with CTE AS (
	SELECT DISTINCT sm.PersonID,s.DateOfContact,s.MethodOfNotification,s.DateDMDCSearchPerformed,s.VerifyBySCRAOrMilOrders
				,s.ActiveAccountEligible,s.BenefitApprovedDeniedPending,s.StatusCode,s.DateBenefitsApplied,s.DateBenefitsEnded,s.[Benefits Effective (as of) Date]
				,s.NotEligReason,s.DenialReason,s.[90DayLetterSentOn],s.BenefitsRecvd,s.Returned,s.AccountNum
	FROM [SCRA_DB_MIGRATE].[dbo].[Sample] s 
	JOIN [dbo].[Servicemember] sm ON s.ServiceMemberID = sm.ServicememberID
	) 
SELECT DISTINCT i.ID,CONVERT(VARCHAR(10),CAST(COALESCE(i.[InquiryDate],cte.DateOfContact,cte.DateDMDCSearchperformed,p.[Timestamp]) as date),121) as [Date]
	  ,COALESCE(t.[Status],CASE i.[IsCompleted] WHEN 0 THEN 'in_process' WHEN 1 THEN 'completed' ELSE NULL END,'qa_completed') as [Status]
      ,CASE  COALESCE(i.[InquiryType],p.[Origin])
			WHEN 'inquiry'			THEN 'Inquiries'
			WHEN 'benefit_request'	THEN 'Benefit intake and eligibility determination'
			WHEN 'dmdc_check'		THEN 'DMDC Validation'
			WHEN 'affiliate'		THEN 'Affiliate or Service By Other'
			ELSE ''
	   END as [RequestTypeOrOrigin]
      ,ISNULL(CAST(p.Id as varchar(9)),'') as [ServicememberID]
      ,ISNULL(p.FirstName,'') as ServicememberFirstName
      ,ISNULL(p.MiddleInitial,'') as ServicememberMiddleInitial
      ,ISNULL(p.LastName,'') as ServicememberLastName
      ,ISNULL(c.FNumber,'') as [FNumber]
      ,ad.ID as ADID
      ,ISNULL(ad.Branch,'') as [Branch]
      ,ISNULL(CAST(ad.IsReserve as varchar(1)),'') as [IsReserve]
      ,ISNULL(CONVERT(VARCHAR(10),ad.NoticeDate, 121),'') as NoticeDate
      ,ISNULL(CONVERT(VARCHAR(10),ad.StartDate, 121),'') as	ADStartDate	
      ,ISNULL(CONVERT(VARCHAR(10),ad.EndDate, 121),'') as ADEndDate
      ,ISNULL(con.ContractNo,'') as [ContractNo]
      ,CASE WHEN ISNULL(con.LegacyNo,'') = '' THEN ISNULL(con.CardNo,'') ELSE ISNULL(con.LegacyNo,'') END as [AccountNumber]
      ,ISNULL(COALESCE(con.ProductName,ct.SUB_PRODUCT_NAME),'') as [ProductType]
      ,ISNULL(CONVERT(VARCHAR(10),con.OpenDate, 121),'') as ProductOpenDate
      ,ISNULL(CONVERT(VARCHAR(10),con.CloseDate, 121),'') as ProductCloseDate
      
      ,ISNULL(COALESCE((SELECT TOP 1 CASE WHEN BenefitApprovedDeniedPending = 'Approved' THEN 'applied' ELSE NULL END FROM CTE cte2 WHERE PersonID = p.ID and cte2.AccountNum = 
				CASE WHEN ISNULL(con.LegacyNo,'') = '' THEN ISNULL(con.CardNo,'') ELSE ISNULL(con.LegacyNo,'') END), 
				(SELECT top 1 b.[Status] FROM [dbo].[Benefit] b LEFT JOIN [dbo].[BenefitDetail] bd ON b.ID = bd.BenefitId WHERE b.PersonID = p.ID AND b.ContractID = con.ID and  b.ActiveDutyID = ad.ID)),'') as [BenefitStatus]
      ,ISNULL(COALESCE((SELECT top 1 b.[DenialReason] FROM [dbo].[Benefit] b LEFT JOIN [dbo].[BenefitDetail] bd ON b.ID = bd.BenefitId WHERE b.PersonID = p.ID AND b.ContractID = con.ID and  b.ActiveDutyID = ad.ID),cte.DenialReason),'') as [DenialReason]
      ,ISNULL(CONVERT(VARCHAR(10),COALESCE((SELECT top 1 b.[StartDate] FROM [dbo].[Benefit] b LEFT JOIN [dbo].[BenefitDetail] bd ON b.ID = bd.BenefitId WHERE b.PersonID = p.ID AND b.ContractID = con.ID and  b.ActiveDutyID = ad.ID)
			,cast(cte.DateBenefitsApplied as date),(SELECT top 1 bd.BenefitAppliedDate FROM [dbo].[Benefit] b LEFT JOIN [dbo].[BenefitDetail] bd ON b.ID = bd.BenefitId WHERE b.PersonID = p.ID AND b.ContractID = con.ID and  b.ActiveDutyID = ad.ID)),121),'') as [BenefitStartDate]
      ,ISNULL(CONVERT(VARCHAR(10),CASE WHEN COALESCE((SELECT top 1 b.[StartDate] FROM [dbo].[Benefit] b LEFT JOIN [dbo].[BenefitDetail] bd ON b.ID = bd.BenefitId WHERE b.PersonID = p.ID AND b.ContractID = con.ID and  b.ActiveDutyID = ad.ID),
			cast(cte.DateBenefitsApplied as date)) < 
					COALESCE((SELECT top 1 b.[EndDate] FROM [dbo].[Benefit] b LEFT JOIN [dbo].[BenefitDetail] bd ON b.ID = bd.BenefitId WHERE b.PersonID = p.ID AND b.ContractID = con.ID and  b.ActiveDutyID = ad.ID),
							cast(cte.DateBenefitsEnded as date),(SELECT top 1 bd.BenefitRemovedDate FROM [dbo].[Benefit] b LEFT JOIN [dbo].[BenefitDetail] bd ON b.ID = bd.BenefitId WHERE b.PersonID = p.ID AND b.ContractID = con.ID and  b.ActiveDutyID = ad.ID))
			THEN COALESCE((SELECT top 1 b.[EndDate] FROM [dbo].[Benefit] b LEFT JOIN [dbo].[BenefitDetail] bd ON b.ID = bd.BenefitId WHERE b.PersonID = p.ID AND b.ContractID = con.ID and  b.ActiveDutyID = ad.ID),
					cast(cte.DateBenefitsEnded as date),(SELECT top 1 bd.BenefitRemovedDate FROM [dbo].[Benefit] b LEFT JOIN [dbo].[BenefitDetail] bd ON b.ID = bd.BenefitId WHERE b.PersonID = p.ID AND b.ContractID = con.ID and  b.ActiveDutyID = ad.ID))
			ELSE NULL END,121),'') as [BenefitEndDate]
      ,ISNULL(CONVERT(VARCHAR(10),COALESCE((SELECT top 1 bd.BenefitEffectiveDate FROM [dbo].[Benefit] b LEFT JOIN [dbo].[BenefitDetail] bd ON b.ID = bd.BenefitId WHERE b.PersonID = p.ID AND b.ContractID = con.ID and  b.ActiveDutyID = ad.ID),
			cast(cte.[Benefits Effective (as of) Date] as date)),121),'') as [BenefitEffectiveDate]
      
      ,t.ID as TID
      ,CASE WHEN t.ID IS NULL THEN CONVERT(VARCHAR(10),COALESCE(i.[InquiryDate],cte.DateOfContact,cte.DateDMDCSearchperformed,p.[Timestamp]),121) ELSE
		ISNULL((SELECT MAX([CompletionDate]) FROM (SELECT CONVERT(varchar(10),MAX(st.CompletionDate),121) as [CompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON tt.ID = st.TaskID AND st.Title = 'Log Request' WHERE tt.ID = t.ID and st.[Status]<> 'rejected' GROUP BY st.CompletionDate HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'') END as 'LogRequestDONE'
	  ,CASE WHEN t.ID IS NULL THEN CONVERT(VARCHAR(10),COALESCE(i.[InquiryDate],cte.DateOfContact,cte.DateDMDCSearchperformed,p.[Timestamp]),121) ELSE	
		ISNULL((SELECT MAX([CompletionDate]) FROM (SELECT CONVERT(varchar(10),MAX(st.CompletionDate),121) as [CompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON st.TaskID = tt.ID and st.Title = 'Enter Details' WHERE tt.ID = t.ID and st.[Status]<> 'rejected' GROUP BY st.CompletionDate HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'') END as 'EnterDetailsDONE'
	  ,CASE WHEN t.ID IS NULL THEN CONVERT(VARCHAR(10),COALESCE(i.[InquiryDate],cte.DateOfContact,cte.DateDMDCSearchperformed,p.[Timestamp]),121) ELSE
		ISNULL((SELECT MAX([CompletionDate]) FROM (SELECT CONVERT(varchar(10),MAX(st.CompletionDate),121) as [CompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON st.TaskID = tt.ID and st.Title = 'Military Information' WHERE tt.ID = t.ID and st.[Status]<> 'rejected' GROUP BY st.CompletionDate HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'') END as 'MilitaryInfoDONE'
	  ,CASE WHEN t.ID IS NULL THEN CONVERT(VARCHAR(10),COALESCE(i.[InquiryDate],cte.DateOfContact,cte.DateDMDCSearchperformed,p.[Timestamp]),121) ELSE		
		ISNULL((SELECT MAX([CompletionDate]) FROM (SELECT CONVERT(varchar(10),MAX(st.CompletionDate),121) as [CompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON st.TaskID = tt.ID and st.Title = 'Product Eligibility' WHERE tt.ID = t.ID and st.[Status]<> 'rejected' GROUP BY st.CompletionDate HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'') END as 'ProductEligibilityDONE'
      ,CASE WHEN t.ID IS NULL THEN CONVERT(VARCHAR(10),COALESCE(i.[InquiryDate],cte.DateOfContact,cte.DateDMDCSearchperformed,p.[Timestamp]),121) ELSE		
		ISNULL((SELECT MAX([CompletionDate]) FROM (SELECT CONVERT(varchar(10),MAX(st.CompletionDate),121) as [CompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON st.TaskID = tt.ID and st.Title = 'Respond to the Requester' WHERE tt.ID = t.ID and st.[Status]<> 'rejected' GROUP BY st.CompletionDate HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'') END as 'RespondToRequesterDONE'
      ,CASE WHEN t.ID IS NULL THEN CONVERT(VARCHAR(10),COALESCE(i.[InquiryDate],cte.DateOfContact,cte.DateDMDCSearchperformed,p.[Timestamp]),121) ELSE		
		ISNULL((SELECT MAX([CompletionDate]) FROM (SELECT CONVERT(varchar(10),MAX(st.CompletionDate),121) as [CompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON st.TaskID = tt.ID and st.Title = 'Save all records' WHERE tt.ID = t.ID and st.[Status]<> 'rejected' GROUP BY st.CompletionDate HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'') END as 'SaveAllRecordsDONE'
	  ,CASE WHEN t.ID IS NULL THEN 'Carolyn Cafarelli' ELSE
		ISNULL((SELECT TOP 1 dbo.fnGetUserName(th.CompletedBy) FROM (SELECT st.CompletedBy as [CompletedBy], MAX(st.CompletionDate) as [CompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON st.TaskID = tt.ID and st.Title = 'Save all records' WHERE tt.ID = t.ID and st.[Status]<> 'rejected' GROUP BY st.CompletionDate,st.CompletedBy HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'') END as 'CompletedBy'

      ,ISNULL((SELECT MAX([CompletionDate]) FROM (SELECT CONVERT(varchar(10),MAX(st.CompletionDate),121) as [CompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON tt.ID = st.TaskID AND st.Title = 'Log Request' WHERE tt.ID = t.ID and st.[Status] = 'rejected' GROUP BY st.CompletionDate HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'') as 'LogRequestREJECTED'
      ,ISNULL((SELECT MAX([CompletionDate]) FROM (SELECT CONVERT(varchar(10),MAX(st.CompletionDate),121) as [CompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON st.TaskID = tt.ID and st.Title = 'Enter Details' WHERE tt.ID = t.ID and st.[Status] = 'rejected' GROUP BY st.CompletionDate HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'')  as 'EnterDetailsREJECTED'
      ,ISNULL((SELECT MAX([CompletionDate]) FROM (SELECT CONVERT(varchar(10),MAX(st.CompletionDate),121) as [CompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON st.TaskID = tt.ID and st.Title = 'Military Information' WHERE tt.ID = t.ID and st.[Status] = 'rejected' GROUP BY st.CompletionDate HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'') as 'MilitaryInfoREJECTED'
	  ,ISNULL((SELECT MAX([CompletionDate]) FROM (SELECT CONVERT(varchar(10),MAX(st.CompletionDate),121) as [CompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON st.TaskID = tt.ID and st.Title = 'Product Eligibility' WHERE tt.ID = t.ID and st.[Status] = 'rejected' GROUP BY st.CompletionDate HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'') as 'ProductEligibilityREJECTED'
	  ,ISNULL((SELECT MAX([CompletionDate]) FROM (SELECT CONVERT(varchar(10),MAX(st.CompletionDate),121) as [CompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON st.TaskID = tt.ID and st.Title = 'Respond to the Requester' WHERE tt.ID = t.ID and st.[Status] = 'rejected' GROUP BY st.CompletionDate HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'') as 'RespondToRequesterREJECTED'
	  ,ISNULL((SELECT MAX([CompletionDate]) FROM (SELECT CONVERT(varchar(10),MAX(st.CompletionDate),121) as [CompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON st.TaskID = tt.ID and st.Title = 'Save all records' WHERE tt.ID = t.ID and st.[Status] = 'rejected' GROUP BY st.CompletionDate HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'') as 'SaveAllRecordsREJECTED'
	  ,ISNULL((SELECT TOP 1 dbo.fnGetUserName(th.CompletedBy) FROM (SELECT st.CompletedBy as [CompletedBy], MAX(st.CompletionDate) as [CompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON st.TaskID = tt.ID and st.Title = 'Save all records' WHERE tt.ID = t.ID and st.[Status] = 'rejected' GROUP BY st.CompletionDate,st.CompletedBy HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'') as 'RejectedBy'

      ,CASE WHEN t.ID IS NULL THEN CONVERT(VARCHAR(10),COALESCE(i.[InquiryDate],cte.DateOfContact,cte.DateDMDCSearchperformed,p.[Timestamp]),121) ELSE
		ISNULL((SELECT MAX(QaCompletionDate) FROM (SELECT CONVERT(varchar(10),MAX(st.QaCompletionDate),121) as [QaCompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON tt.ID = st.TaskID AND st.Title = 'Log Request' WHERE tt.ID = t.ID and st.[Status] = 'qa_completed' GROUP BY st.CompletionDate HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'') END as 'QaLogRequestDONE'
	  ,CASE WHEN t.ID IS NULL THEN CONVERT(VARCHAR(10),COALESCE(i.[InquiryDate],cte.DateOfContact,cte.DateDMDCSearchperformed,p.[Timestamp]),121) ELSE
		ISNULL((SELECT MAX(QaCompletionDate) FROM (SELECT CONVERT(varchar(10),MAX(st.QaCompletionDate),121) as [QaCompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON st.TaskID = tt.ID and st.Title = 'Enter Details' WHERE tt.ID = t.ID and st.[Status] = 'qa_completed' GROUP BY st.CompletionDate HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'') END as 'QaEnterDetailsDONE'
	  ,CASE WHEN t.ID IS NULL THEN CONVERT(VARCHAR(10),COALESCE(i.[InquiryDate],cte.DateOfContact,cte.DateDMDCSearchperformed,p.[Timestamp]),121) ELSE
		ISNULL((SELECT MAX(QaCompletionDate) FROM (SELECT CONVERT(varchar(10),MAX(st.QaCompletionDate),121) as [QaCompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON st.TaskID = tt.ID and st.Title = 'Military Information' WHERE tt.ID = t.ID and st.[Status] = 'qa_completed' GROUP BY st.CompletionDate HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'') END as 'QaMilitaryInfoDONE'
	  ,CASE WHEN t.ID IS NULL THEN CONVERT(VARCHAR(10),COALESCE(i.[InquiryDate],cte.DateOfContact,cte.DateDMDCSearchperformed,p.[Timestamp]),121) ELSE
		ISNULL((SELECT MAX(QaCompletionDate) FROM (SELECT CONVERT(varchar(10),MAX(st.QaCompletionDate),121) as [QaCompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON st.TaskID = tt.ID and st.Title = 'Product Eligibility' WHERE tt.ID = t.ID and st.[Status] = 'qa_completed' GROUP BY st.CompletionDate HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'') END as 'QaProductEligibilityDONE'
	  ,CASE WHEN t.ID IS NULL THEN CONVERT(VARCHAR(10),COALESCE(i.[InquiryDate],cte.DateOfContact,cte.DateDMDCSearchperformed,p.[Timestamp]),121) ELSE
		ISNULL((SELECT MAX(QaCompletionDate) FROM (SELECT CONVERT(varchar(10),MAX(st.QaCompletionDate),121) as [QaCompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON st.TaskID = tt.ID and st.Title = 'Respond to the Requester' WHERE tt.ID = t.ID and st.[Status] = 'qa_completed' GROUP BY st.CompletionDate HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'') END as 'QaRespondToRequesterDONE'
	  ,CASE WHEN t.ID IS NULL THEN CONVERT(VARCHAR(10),COALESCE(i.[InquiryDate],cte.DateOfContact,cte.DateDMDCSearchperformed,p.[Timestamp]),121) ELSE
		ISNULL((SELECT MAX(QaCompletionDate) FROM (SELECT CONVERT(varchar(10),MAX(st.QaCompletionDate),121) as [QaCompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON st.TaskID = tt.ID and st.Title = 'Save all records' WHERE tt.ID = t.ID and st.[Status] = 'qa_completed' GROUP BY st.CompletionDate HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'') END as 'QaSaveAllRecordsDONE'
	  ,CASE WHEN t.ID IS NULL THEN 'Carolyn Cafarelli' ELSE
	  ISNULL((SELECT TOP 1 dbo.fnGetUserName(th.CompletedBy) FROM (SELECT st.CompletedBy as [CompletedBy], MAX(st.QaCompletionDate) as [QaCompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON st.TaskID = tt.ID and st.Title = 'Save all records' WHERE tt.ID = t.ID and st.[Status] = 'qa_completed' GROUP BY st.CompletionDate,st.CompletedBy HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'') END as 'QaCompletedBy'

	  ,CASE WHEN t.ID IS NULL THEN 'Yes' ELSE
			CASE WHEN (SELECT CASE WHEN 
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
			END) IN ('qa_completed','misdirected') THEN 'Yes' ELSE '' END 
		END as [Completed]
	  
  FROM [dbo].[Person] p 
  LEFT JOIN [dbo].[Inquiry] i  ON p.ID = i.ServicememberId
  LEFT JOIN [dbo].[Task] t ON i.ID = t.InquiryID
  LEFT JOIN [dbo].[Customer] c ON p.Id = c.PersonID
  LEFT JOIN (SELECT DISTINCT MAX(ad.ID) as ID,PersonID,StartDate,EndDate,NoticeDate,Branch,IsReserve FROM [dbo].[ActiveDuty] ad JOIN [dbo].[BranchOfService] bs ON ad.BranchOfServiceID = bs.ID
			GROUP BY PersonID,StartDate,EndDate,NoticeDate,Branch,IsReserve HAVING StartDate = (SELECT MAX(StartDate) FROM [dbo].[ActiveDuty] ad2 WHERE ad2.PersonID = ad.PersonID) AND 
			(EndDate = (SELECT MAX(EndDate) FROM [dbo].[ActiveDuty] ad2 WHERE ad2.PersonID = ad.PersonID) OR EndDate IS NULL)) ad ON p.ID = ad.PersonID
  LEFT JOIN [dbo].[Contract] con ON p.Id = con.PersonID and con.IsDeleted = 0
  LEFT JOIN [dbo].[ContractType] ct ON con.ContractTypeId = ct.ID
  LEFT JOIN CTE cte ON p.ID = cte.PersonID
  WHERE 1=1  
	AND COALESCE(i.[InquiryType],p.[Origin]) = 'benefit_request'
	AND p.ID NOT IN (SELECT DISTINCT PersonInquiringId FROM [dbo].[Inquiry] WHERE PersonInquiringId <> ServicememberId)
  
	AND ((CAST(COALESCE(i.[InquiryDate],cte.DateOfContact,cte.DateDMDCSearchperformed,p.[Timestamp]) as DATE)
		BETWEEN DATEADD(wk,datediff(wk,0,dateadd(wk,0,@ReportDate)),0) AND DATEADD(wk,datediff(ww,0,dateadd(wk,0,@ReportDate)),6))
		OR ((CAST(COALESCE(i.[InquiryDate],cte.DateOfContact,cte.DateDMDCSearchperformed,p.[Timestamp]) as DATE)
		NOT BETWEEN DATEADD(wk,datediff(wk,0,dateadd(wk,0,@ReportDate)),0) AND DATEADD(wk,datediff(wk,0,dateadd(wk,0,@ReportDate)),6) 
		AND
		COALESCE(t.[Status],CASE i.[IsCompleted] WHEN 0 THEN 'in_process' WHEN 1 THEN 'completed' ELSE NULL END,'qa_completed') <> 'qa_completed'))
		)
	
ORDER BY CONVERT(VARCHAR(10),CAST(COALESCE(i.[InquiryDate],cte.DateOfContact,cte.DateDMDCSearchperformed,p.[Timestamp]) as DATE),121) desc

END

/*
DECLARE @date date SET @date = dateadd(wk,0,GETDATE())
PRINT @date
EXEC  [dbo].[spWeeklyReport_Load]
	@ReportDate = @date
*/
GO
/****** Object:  StoredProcedure [dbo].[spInquiries_Report]    Script Date: 05/22/2019 10:19:56 ******/
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
	SELECT DISTINCT i.ID,CAST(CONVERT(VARCHAR(10),[InquiryDate],121) as DATE) as 'Date'
	  ,[InquiryType]
	  ,ISNULL(dbo.fnResponseMethodName(i.[ContactMethodID]),'') as [ContactMethod]
	  
	  ,(SELECT CASE WHEN 
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
		END) as [Status]			 
	  
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
   	  
      ,ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE([Description],CHAR(10)+CHAR(13),'|'),CHAR(10),'|'),CHAR(13),'|'),CHAR(9),'    '),'|||','|'),'||','|'),CHAR(226)+CHAR(128)+CHAR(147),'-'),'') as [Description]
      ,ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE([Comment],CHAR(10)+CHAR(13),'|'),CHAR(10),'|'),CHAR(13),'|'),CHAR(9),'    '),'|||','|'),'||','|'),CHAR(226)+CHAR(128)+CHAR(147),'-'),'') as [Comment]
      ,ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE([ResponseText],CHAR(10)+CHAR(13),'|'),CHAR(10),'|'),CHAR(13),'|'),CHAR(9),'    '),'|||','|'),'||','|'),CHAR(226)+CHAR(128)+CHAR(147),'-'),'') as [ResponseText]
      ,ISNULL(CONVERT(VARCHAR(10),[ResponseDate],121),'') as [ResponseDate]
      ,ISNULL(dbo.fnResponseMethodName([ResponseMethodId]),'') as [ResponseMethod]
						
		,CASE WHEN (SELECT CASE WHEN 
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
		END) IN ('completed','qa_completed','misdirected') THEN 'Yes' ELSE '' END as [Completed]
      
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
    
  ORDER BY CAST(CONVERT(VARCHAR(10),[InquiryDate],121) as DATE) DESC
  
END


/*

--DECLARE @date date SET @date = dateadd(wk,-1,getdate())
--SELECT @date
EXEC [dbo].[spInquiries_Report]
	--@ReportDate = @date
	
*/
GO
/****** Object:  StoredProcedure [dbo].[spDMDC_Validation_Report]    Script Date: 05/22/2019 10:19:56 ******/
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
	  
	  --,COALESCE(t.[Status],CASE i.[IsCompleted] WHEN 0 THEN 'in_process' WHEN 1 THEN 'completed' ELSE '' END) as [Status]
	  
	  ,COALESCE((SELECT CASE WHEN 
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
		END), CASE i.[IsCompleted] WHEN 0 THEN 'in_process' WHEN 1 THEN 'completed' ELSE '' END) as [Status]
	  
	  ,ISNULL(i.PersonInquiringId,'') as [PersonRequestingId]
	  ,ISNULL((SELECT FirstName FROM [dbo].[Person] WHERE [ID] = i.PersonInquiringId),'') as [PersonRequestingFirstName]
	  ,ISNULL((SELECT LastName FROM [dbo].[Person] WHERE [ID] = i.PersonInquiringId),'') as [PersonRequestingLastName]
	  
	  ,ISNULL(CAST(p.Id as varchar(9)),'') as [ServicememberID]
      ,ISNULL(p.FirstName,'') as ServicememberFirstName
      ,ISNULL(p.MiddleInitial,'') as ServicememberMiddleInitial
      ,ISNULL(p.LastName,'') as ServicememberLastName
     
	  ,ISNULL((SELECT MAX([CompletionDate]) FROM (SELECT CONVERT(varchar(10),MAX(st.CompletionDate),121) as [CompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON tt.ID = st.TaskID AND st.Title = 'Log Request' WHERE tt.ID = t.ID and st.[Status]<> 'rejected' GROUP BY st.CompletionDate HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'') as 'LogRequestDone'
      ,ISNULL((SELECT TOP 1 dbo.fnGetUserName(th.CompletedBy) FROM (SELECT st.CompletedBy as [CompletedBy], MAX(st.CompletionDate) as [CompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON tt.ID = st.TaskID AND st.Title = 'Log Request' WHERE tt.ID = t.ID and st.[Status]<> 'rejected' GROUP BY st.CompletionDate,st.CompletedBy HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'') as 'LogRequestCompletedBy'
      --,ISNULL((SELECT MAX([CompletionDate]) FROM (SELECT CONVERT(varchar(10),MAX(st.CompletionDate),121) as [CompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON st.TaskID = tt.ID and st.Title = 'Enter Details' WHERE tt.ID = t.ID and st.[Status]<> 'rejected' GROUP BY st.CompletionDate HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'')  as 'EnterDetailsDone'
      --,ISNULL((SELECT TOP 1 dbo.fnGetUserName(th.CompletedBy) FROM (SELECT st.CompletedBy as [CompletedBy], MAX(st.CompletionDate) as [CompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON st.TaskID = tt.ID and st.Title = 'Enter Details' WHERE tt.ID = t.ID and st.[Status]<> 'rejected' GROUP BY st.CompletionDate,st.CompletedBy HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'')  as 'EnterDetailsCompletedBy'
      --,ISNULL((SELECT MAX([CompletionDate]) FROM (SELECT CONVERT(varchar(10),MAX(st.CompletionDate),121) as [CompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON st.TaskID = tt.ID and st.Title = 'Respond to the Requester' WHERE tt.ID = t.ID and st.[Status]<> 'rejected' GROUP BY st.CompletionDate HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'') as 'RespondtoRequesterDone'
      --,ISNULL((SELECT TOP 1 dbo.fnGetUserName(th.CompletedBy) FROM (SELECT st.CompletedBy as [CompletedBy], MAX(st.CompletionDate) as [CompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON st.TaskID = tt.ID and st.Title = 'Respond to the Requester' WHERE tt.ID = t.ID and st.[Status]<> 'rejected' GROUP BY st.CompletionDate,st.CompletedBy HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'') as 'RespondtoRequesterCompletedBy'
      --,ISNULL((SELECT MAX([CompletionDate]) FROM (SELECT CONVERT(varchar(10),MAX(st.CompletionDate),121) as [CompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON st.TaskID = tt.ID and st.Title = 'Save all records' WHERE tt.ID = t.ID and st.[Status]<> 'rejected' GROUP BY st.CompletionDate HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'') as 'SaveAllRecordsDone'
      --,ISNULL((SELECT TOP 1 dbo.fnGetUserName(th.CompletedBy) FROM (SELECT st.CompletedBy as [CompletedBy], MAX(st.CompletionDate) as [CompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON st.TaskID = tt.ID and st.Title = 'Save all records' WHERE tt.ID = t.ID and st.[Status]<> 'rejected' GROUP BY st.CompletionDate,st.CompletedBy HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'') as 'SaveAllRecordsCompletedBy'
		      
      ,ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE([Description],CHAR(10)+CHAR(13),'|'),CHAR(10),'|'),CHAR(13),'|'),CHAR(9),'    '),'|||','|'),'') as [Description]
      ,ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE([Comment],CHAR(10)+CHAR(13),'|'),CHAR(10),'|'),CHAR(13),'|'),CHAR(9),'    '),'|||','|'),'') as [Comment]
      
      
      ,ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE([ResponseText],CHAR(10)+CHAR(13),'|'),CHAR(10),'|'),CHAR(13),'|'),CHAR(9),'    '),'|||','|'),'') as [ResponseText]
      ,ISNULL(CONVERT(VARCHAR(10),[ResponseDate],121),'') as [ResponseDate]
      ,ISNULL(dbo.fnResponseMethodName([ResponseMethodId]),'') as [ResponseMethod]
      
      --,ISNULL([IdentificationMethod],'') as [IdentificationMethod]
      ,ISNULL(CONVERT(VARCHAR(10),[DMDCValidationDate],121),'') as [DMDCValidationDate]
      
      ,ISNULL(CASE WHEN ad.PersonID IS NOT NULL THEN 'Yes' ELSE '' END,'') as [ServicememberOnActiveDuty]
      
      --,COALESCE(CASE WHEN t.[Status] = 'completed' OR t.[Status] = 'qa_completed' THEN 'Yes' ELSE NULL END,CASE [IsCompleted] WHEN 0 THEN '' WHEN 1 THEN 'Yes' ELSE '' END) as [Completed]
      
      ,CASE WHEN COALESCE((SELECT CASE WHEN 
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
		END), CASE i.[IsCompleted] WHEN 0 THEN 'in_process' WHEN 1 THEN 'completed' ELSE '' END) IN ('completed','qa_completed','misdirected') THEN 'Yes' ELSE '' END as [Completed]
      
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

	  WHERE [InquiryType] = 'dmdc_check'
	  ORDER BY CAST(CONVERT(VARCHAR(10),[InquiryDate],121) as DATE) DESC


END


/*

--DECLARE @date date SET @date = dateadd(wk,-1,getdate())
--SELECT @date
EXEC [dbo].[spDMDC_Validation_Report]
	--@ReportDate = @date
	
*/
GO
/****** Object:  StoredProcedure [dbo].[spAffiliate_Report]    Script Date: 05/22/2019 10:19:56 ******/
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
	  --,t.[Status]
	  --,COALESCE((SELECT TOP 1 [Status] FROM dbo.SubTask WHERE TaskId = (SELECT ID FROM dbo.Task WHERE InquiryID = i.ID) GROUP BY [Title],[Status],[Timestamp] 
			--	 HAVING [Timestamp] = MAX([Timestamp]) AND [Title] <> 'Assign QA Agent' ORDER BY [Timestamp] DESC), CASE [IsCompleted] WHEN 0 THEN 'in_process' WHEN 1 THEN 'completed' ELSE '' END) as [Status]
	  
	  ,(SELECT CASE WHEN 
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
		END) as [Status]
	  	  
	  ,ISNULL(i.PersonInquiringId,'') as [PersonRequestingId]
	  ,ISNULL((SELECT FirstName FROM [dbo].[Person] WHERE [ID] = i.PersonInquiringId),'') as [PersonRequestingFirstName]
	  ,ISNULL((SELECT LastName FROM [dbo].[Person] WHERE [ID] = i.PersonInquiringId),'') as [PersonRequestingLastName]
	  
	  ,ISNULL((SELECT Email FROM [dbo].[Person] WHERE [ID] = i.PersonInquiringId),'') as [PersonRequestingEmail]
	  ,ISNULL((SELECT REPLACE(Phone,'0000000000','') FROM [dbo].[Person] WHERE [ID] = i.PersonInquiringId),'') as [PersonRequestingPhone]
	  ,ISNULL((SELECT REPLACE(REPLACE(REPLACE(REPLACE(REPLACE([Address1]+', '+City+', '+[State]+' '+[Zip],', ,  000000000',''),', ,  ',''),', , ',''),'000000000',''),'0000','') FROM [dbo].[Person] WHERE [ID] = i.PersonInquiringId),'') as [PersonRequestingAddress]
	  
	  ,ISNULL(CAST(p.Id as varchar(9)),'') as [ServicememberID]
      ,ISNULL(p.FirstName,'') as ServicememberFirstName
      ,ISNULL(p.MiddleInitial,'') as ServicememberMiddleInitial
      ,ISNULL(p.LastName,'') as ServicememberLastName
     
      ,ISNULL((SELECT MAX([CompletionDate]) FROM (SELECT CONVERT(varchar(10),MAX(st.CompletionDate),121) as [CompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON tt.ID = st.TaskID AND st.Title = 'Log Request' WHERE tt.ID = t.ID and st.[Status] <> 'rejected' GROUP BY st.CompletionDate HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'') as 'LogRequestDone'
      ,ISNULL((SELECT TOP 1 dbo.fnGetUserName(th.CompletedBy) FROM (SELECT st.CompletedBy as [CompletedBy], MAX(st.CompletionDate) as [CompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON tt.ID = st.TaskID AND st.Title = 'Log Request' WHERE tt.ID = t.ID and st.[Status] <> 'rejected' GROUP BY st.CompletionDate,st.CompletedBy HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'') as 'LogRequestCompletedBy'
   --   ,ISNULL((SELECT MAX([CompletionDate]) FROM (SELECT CONVERT(varchar(10),MAX(st.CompletionDate),121) as [CompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON st.TaskID = tt.ID and st.Title = 'Enter Details' WHERE tt.ID = t.ID and st.[Status] <> 'rejected' GROUP BY st.CompletionDate HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'')  as 'EnterDetailsDone'
   --   ,ISNULL((SELECT TOP 1 dbo.fnGetUserName(th.CompletedBy) FROM (SELECT st.CompletedBy as [CompletedBy], MAX(st.CompletionDate) as [CompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON st.TaskID = tt.ID and st.Title = 'Enter Details' WHERE tt.ID = t.ID and st.[Status] <> 'rejected' GROUP BY st.CompletionDate,st.CompletedBy HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'')  as 'EnterDetailsCompletedBy'
   --   ,ISNULL((SELECT MAX([CompletionDate]) FROM (SELECT CONVERT(varchar(10),MAX(st.CompletionDate),121) as [CompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON st.TaskID = tt.ID and st.Title = 'Respond to the Requester' WHERE tt.ID = t.ID and st.[Status] <> 'rejected' GROUP BY st.CompletionDate HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'') as 'RespondtoRequesterDone'
   --   ,ISNULL((SELECT TOP 1 dbo.fnGetUserName(th.CompletedBy) FROM (SELECT st.CompletedBy as [CompletedBy], MAX(st.CompletionDate) as [CompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON st.TaskID = tt.ID and st.Title = 'Respond to the Requester' WHERE tt.ID = t.ID and st.[Status] <> 'rejected' GROUP BY st.CompletionDate,st.CompletedBy HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'') as 'RespondtoRequesterCompletedBy'
   --   ,ISNULL((SELECT MAX([CompletionDate]) FROM (SELECT CONVERT(varchar(10),MAX(st.CompletionDate),121) as [CompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON st.TaskID = tt.ID and st.Title = 'Save all records' WHERE tt.ID = t.ID and st.[Status] <> 'rejected' GROUP BY st.CompletionDate HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'') as 'SaveAllRecordsDone'
   --   ,ISNULL((SELECT TOP 1 dbo.fnGetUserName(th.CompletedBy) FROM (SELECT st.CompletedBy as [CompletedBy], MAX(st.CompletionDate) as [CompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON st.TaskID = tt.ID and st.Title = 'Save all records' WHERE tt.ID = t.ID and st.[Status] <> 'rejected' GROUP BY st.CompletionDate,st.CompletedBy HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'') as 'SaveAllRecordsCompletedBy'
	  
   --   ,ISNULL((SELECT MAX([CompletionDate]) FROM (SELECT CONVERT(varchar(10),MAX(st.CompletionDate),121) as [CompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON tt.ID = st.TaskID AND st.Title = 'Log Request' WHERE tt.ID = t.ID and st.[Status] = 'rejected' GROUP BY st.CompletionDate HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'') as 'LogRequestRejected'
   --   ,ISNULL((SELECT TOP 1 dbo.fnGetUserName(th.CompletedBy) FROM (SELECT st.CompletedBy as [CompletedBy], MAX(st.CompletionDate) as [CompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON tt.ID = st.TaskID AND st.Title = 'Log Request' WHERE tt.ID = t.ID and st.[Status] = 'rejected' GROUP BY st.CompletionDate,st.CompletedBy HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'') as 'LogRequestRejectedBy'
   --   ,ISNULL((SELECT MAX([CompletionDate]) FROM (SELECT CONVERT(varchar(10),MAX(st.CompletionDate),121) as [CompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON st.TaskID = tt.ID and st.Title = 'Enter Details' WHERE tt.ID = t.ID and st.[Status] = 'rejected' GROUP BY st.CompletionDate HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'')  as 'EnterDetailsRejected'
   --   ,ISNULL((SELECT TOP 1 dbo.fnGetUserName(th.CompletedBy) FROM (SELECT st.CompletedBy as [CompletedBy], MAX(st.CompletionDate) as [CompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON st.TaskID = tt.ID and st.Title = 'Enter Details' WHERE tt.ID = t.ID and st.[Status] = 'rejected' GROUP BY st.CompletionDate,st.CompletedBy HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'')  as 'EnterDetailsRejectedBy'
   --   ,ISNULL((SELECT MAX([CompletionDate]) FROM (SELECT CONVERT(varchar(10),MAX(st.CompletionDate),121) as [CompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON st.TaskID = tt.ID and st.Title = 'Respond to the Requester' WHERE tt.ID = t.ID and st.[Status] = 'rejected' GROUP BY st.CompletionDate HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'') as 'RespondtoRequesterRejected'
   --   ,ISNULL((SELECT TOP 1 dbo.fnGetUserName(th.CompletedBy) FROM (SELECT st.CompletedBy as [CompletedBy], MAX(st.CompletionDate) as [CompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON st.TaskID = tt.ID and st.Title = 'Respond to the Requester' WHERE tt.ID = t.ID and st.[Status] = 'rejected' GROUP BY st.CompletionDate,st.CompletedBy HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'') as 'RespondtoRequesterRejectedBy'
   --   ,ISNULL((SELECT MAX([CompletionDate]) FROM (SELECT CONVERT(varchar(10),MAX(st.CompletionDate),121) as [CompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON st.TaskID = tt.ID and st.Title = 'Save all records' WHERE tt.ID = t.ID and st.[Status] = 'rejected' GROUP BY st.CompletionDate HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'') as 'SaveAllRecordsRejected'
   --   ,ISNULL((SELECT TOP 1 dbo.fnGetUserName(th.CompletedBy) FROM (SELECT st.CompletedBy as [CompletedBy], MAX(st.CompletionDate) as [CompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON st.TaskID = tt.ID and st.Title = 'Save all records' WHERE tt.ID = t.ID and st.[Status] = 'rejected' GROUP BY st.CompletionDate,st.CompletedBy HAVING st.CompletionDate = MAX(st.CompletionDate)) th),'') as 'SaveAllRecordsRejectedBy'
	  
   --   ,ISNULL((SELECT MAX([QaCompletionDate]) FROM (SELECT CONVERT(varchar(10),MAX(st.QaCompletionDate),121) as [QaCompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON tt.ID = st.TaskID AND st.Title = 'Log Request' WHERE tt.ID = t.ID and st.[Status] = 'qa_completed' GROUP BY st.QaCompletionDate HAVING st.QaCompletionDate = MAX(st.QaCompletionDate)) th),'') as 'QaLogRequestDone'
   --   ,ISNULL((SELECT TOP 1 dbo.fnGetUserName(th.QaCompletedBy) FROM (SELECT st.QaCompletedBy as [QaCompletedBy], MAX(st.QaCompletionDate) as [QaCompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON tt.ID = st.TaskID AND st.Title = 'Log Request' WHERE tt.ID = t.ID and st.[Status] = 'qa_completed' GROUP BY st.QaCompletionDate,st.QaCompletedBy HAVING st.QaCompletionDate = MAX(st.QaCompletionDate)) th),'') as 'QaLogRequestCompletedBy'
   --   ,ISNULL((SELECT MAX([QaCompletionDate]) FROM (SELECT CONVERT(varchar(10),MAX(st.CompletionDate),121) as [QaCompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON st.TaskID = tt.ID and st.Title = 'Enter Details' WHERE tt.ID = t.ID and st.[Status] = 'qa_completed' GROUP BY st.QaCompletionDate HAVING st.QaCompletionDate = MAX(st.QaCompletionDate)) th),'')  as 'QaEnterDetailsDone'
   --   ,ISNULL((SELECT TOP 1 dbo.fnGetUserName(th.QaCompletedBy) FROM (SELECT st.QaCompletedBy as [QaCompletedBy], MAX(st.QaCompletionDate) as [QaCompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON st.TaskID = tt.ID and st.Title = 'Enter Details' WHERE tt.ID = t.ID and st.[Status] = 'qa_completed' GROUP BY st.QaCompletionDate,st.QaCompletedBy HAVING st.QaCompletionDate = MAX(st.QaCompletionDate)) th),'')  as 'QaEnterDetailsCompletedBy'
   --   ,ISNULL((SELECT MAX([QaCompletionDate]) FROM (SELECT CONVERT(varchar(10),MAX(st.CompletionDate),121) as [QaCompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON st.TaskID = tt.ID and st.Title = 'Respond to the Requester' WHERE tt.ID = t.ID and st.[Status] = 'qa_completed' GROUP BY st.QaCompletionDate HAVING st.QaCompletionDate = MAX(st.QaCompletionDate)) th),'') as 'QaRespondtoRequesterDone'
   --   ,ISNULL((SELECT TOP 1 dbo.fnGetUserName(th.QaCompletedBy) FROM (SELECT st.QaCompletedBy as [QaCompletedBy], MAX(st.QaCompletionDate) as [QaCompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON st.TaskID = tt.ID and st.Title = 'Respond to the Requester' WHERE tt.ID = t.ID and st.[Status] = 'qa_completed' GROUP BY st.QaCompletionDate,st.QaCompletedBy HAVING st.QaCompletionDate = MAX(st.QaCompletionDate)) th),'') as 'QaRespondtoRequesterCompletedBy'
   --   ,ISNULL((SELECT MAX([QaCompletionDate]) FROM (SELECT CONVERT(varchar(10),MAX(st.CompletionDate),121) as [QaCompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON st.TaskID = tt.ID and st.Title = 'Save all records' WHERE tt.ID = t.ID and st.[Status] = 'qa_completed' GROUP BY st.QaCompletionDate HAVING st.QaCompletionDate = MAX(st.QaCompletionDate)) th),'') as 'QaSaveAllRecordsDone'
   --   ,ISNULL((SELECT TOP 1 dbo.fnGetUserName(th.QaCompletedBy) FROM (SELECT st.QaCompletedBy as [QaCompletedBy], MAX(st.QaCompletionDate) as [QaCompletionDate] FROM [dbo].[Task] tt JOIN [dbo].[SubTask] st ON st.TaskID = tt.ID and st.Title = 'Save all records' WHERE tt.ID = t.ID and st.[Status] = 'qa_completed' GROUP BY st.QaCompletionDate,st.QaCompletedBy HAVING st.QaCompletionDate = MAX(st.QaCompletionDate)) th),'') as 'QaSaveAllRecordsCompletedBy'
	  
      ,ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE([Description],CHAR(10)+CHAR(13),'|'),CHAR(10),'|'),CHAR(13),'|'),CHAR(9),'    '),'|||','|'),'||','|'),CHAR(226)+CHAR(128)+CHAR(147),'-'),'') as [Description]
      ,ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE([Comment],CHAR(10)+CHAR(13),'|'),CHAR(10),'|'),CHAR(13),'|'),CHAR(9),'    '),'|||','|'),'||','|'),CHAR(226)+CHAR(128)+CHAR(147),'-'),'') as [Comment]
      ,ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE([ResponseText],CHAR(10)+CHAR(13),'|'),CHAR(10),'|'),CHAR(13),'|'),CHAR(9),'    '),'|||','|'),'||','|'),CHAR(226)+CHAR(128)+CHAR(147),'-'),'') as [ResponseText]
      ,ISNULL(CONVERT(VARCHAR(10),[ResponseDate],121),'') as [ResponseDate]
      ,ISNULL(dbo.fnResponseMethodName([ResponseMethodId]),'') as [ResponseMethod]
      
      ,ISNULL(CONVERT(VARCHAR(10),i.ScusaSentDate1,121),'') as ScusaSentDate1
      ,ISNULL(CONVERT(VARCHAR(10),i.ScusaSentDate2,121),'') as ScusaSentDate2
      ,ISNULL(CONVERT(VARCHAR(10),i.ScusaConfirmationDate,121),'') as ScusaConfirmationDate
      
      --,ISNULL([IdentificationMethod],'') as [IdentificationMethod]
      --,ISNULL(CONVERT(VARCHAR(10),[DMDCValidationDate],121),'') as [DMDCValidationDate]
      
      -- ,CASE WHEN (SELECT TOP 1 [Status] FROM dbo.SubTask WHERE TaskId = (SELECT ID FROM dbo.Task WHERE InquiryID = i.ID) GROUP BY [Title],[Status],[Timestamp] 
						--HAVING [Timestamp] = MAX([Timestamp]) AND [Title] <> 'Assign QA Agent' ORDER BY [Timestamp] DESC) IN ('qa_completed','completed','misdirected') THEN 'Yes' ELSE '' END as [Completed]
						
		,CASE WHEN (SELECT CASE WHEN 
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
		END) IN ('completed','qa_completed','misdirected') THEN 'Yes' ELSE '' END as [Completed]						
						
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
/****** Object:  StoredProcedure [dbo].[sp30DaysList_Report]    Script Date: 05/22/2019 10:19:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[sp30DaysList_Report]
WITH RECOMPILE
AS
	SET NOCOUNT ON;
	SELECT DISTINCT 
		  p.ID
		 ,p.LastName
		 ,p.FirstName
		 ,cus.FNumber
		 ,COALESCE(bd.ExpectedRemovalDate,bd.BenefitRemovedDate) as BenefitRemovedDate
		 ,DateDiff(DAY,CAST(GETDATE() as DATE),COALESCE(bd.ExpectedRemovalDate,bd.BenefitRemovedDate)) AS DaysLeft
		 ,ct.SUB_PRODUCT_NAME
	FROM dbo.Person p 
		INNER JOIN dbo.Customer cus 
			ON p.ID = cus.PersonID
		INNER JOIN dbo.[Contract] c 
			ON p.ID  = c.PersonID
		INNER JOIN dbo.ContractType ct 
			ON c.ContractTypeId = ct.ID
		INNER JOIN dbo.Benefit b 
			ON c.ID = b.ContractID
		INNER JOIN dbo.BenefitDetail bd 
			ON b.ID = bd.BenefitId 
	WHERE (((DateDiff(DAY,CAST(GETDATE() as DATE),COALESCE(bd.ExpectedRemovalDate,bd.BenefitRemovedDate))) BETWEEN 0 AND 30))
		ORDER BY (DateDiff(DAY,CAST(GETDATE() as DATE),COALESCE(bd.ExpectedRemovalDate,bd.BenefitRemovedDate)))

/*
EXEC [dbo].[sp30DaysList_Report]
*/
GO
