USE [SCRA_DB]
GO
/****** Object:  StoredProcedure [dbo].[spServiceMember_Expired_Denied_Active_Report]    Script Date: 05/15/2019 11:21:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[spServiceMember_Expired_Denied_Active_Report]
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
		,COALESCE(cte.BenefitApprovedDeniedPending,
					CASE WHEN ISNULL(b.DenialReason	,'') <> '' THEN 'Denied' 
						ELSE UPPER(SUBSTRING(b.[Status],1,1))+SUBSTRING(b.[Status],2,LEN(b.[Status])-1) END)
											AS BenefitApprovedDeniedPending
		,COALESCE(cte.StatusCode, 
					CASE WHEN ISNULL(b.DenialReason	,'') <> '' THEN 'Not Eligible' 
					ELSE 
						CASE WHEN b.[Status] IN ('applying','applied','removing') THEN 'Active Duty' ELSE NULL END END)
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
		,ct.CATEGORY_ORIGIN					AS ProductType
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
		
		outer apply( Select distinct ID,CommunicationDate,LetterId, TaskId  from dbo.Communication where PersonID in (Select pp.ID As PersonId from Person pp 
						where pp.ID in (Select pl.ToID from PersonToPersonLink pl where pl.FromID = p.ID) 
							OR pp.ID  in (Select pl.FromID from PersonToPersonLink pl where pl.ToID = p.ID) OR pp.ID = p.ID)) com
		
		outer apply (Select distinct  ContactMethodID from dbo.Inquiry where COALESCE(ServicememberId,PersonInquiringId) in (Select pp.ID As PersonId from Person pp 
						where pp.ID in (Select pl.ToID from PersonToPersonLink pl where pl.FromID = p.ID) 
							OR pp.ID  in (Select pl.FromID from PersonToPersonLink pl where pl.ToID = p.ID) OR pp.ID = p.ID)) as r
		LEFT JOIN dbo.ContactMethod cm 
			ON r.ContactMethodId = cm.ID
			
		outer apply(Select distinct FNumber from dbo.Customer where PersonID=p.ID and PersonID in (Select pp.ID As PersonId from Person pp 
						where pp.ID in (Select pl.ToID from PersonToPersonLink pl where pl.FromID = p.ID) 
							OR pp.ID  in (Select pl.FromID from PersonToPersonLink pl where pl.ToID = p.ID) OR pp.ID = p.ID)) cust
							
		outer apply(select distinct Comment from dbo.Note where PersonID in (Select pp.ID As PersonId from Person pp 
						where pp.ID in (Select pl.ToID from PersonToPersonLink pl where pl.FromID = p.ID) 
							OR pp.ID  in (Select pl.FromID from PersonToPersonLink pl where pl.ToID = p.ID) OR pp.ID = p.ID)) note
		
		outer apply (select * from dbo.Benefit where PersonID in (Select pp.ID As PersonId from Person pp 
						where pp.ID in (Select pl.ToID from PersonToPersonLink pl where pl.FromID = p.ID) 
							OR pp.ID  in (Select pl.FromID from PersonToPersonLink pl where pl.ToID = p.ID) OR pp.ID = p.ID)) b
		LEFT JOIN dbo.BenefitDetail bd 
			ON b.ID = bd.BenefitId
		
		outer apply (select * from dbo.[Contract] where b.ContractID = ID AND IsDeleted = 0 AND PersonID in (Select pp.ID As PersonId from Person pp 
						where pp.ID in (Select pl.ToID from PersonToPersonLink pl where pl.FromID = p.ID) 
							OR pp.ID  in (Select pl.FromID from PersonToPersonLink pl where pl.ToID = p.ID) OR pp.ID = p.ID)) cnt
		LEFT JOIN dbo.ContractType ct 
			ON cnt.ContractTypeId = ct.ID
		
		outer apply (Select * from dbo.ActiveDuty where PersonID in (Select pp.ID As PersonId from Person pp 
						where pp.ID in (Select pl.ToID from PersonToPersonLink pl where pl.FromID = p.ID) 
							OR pp.ID  in (Select pl.FromID from PersonToPersonLink pl where pl.ToID = p.ID) OR pp.ID = p.ID)) ad
		INNER JOIN dbo.BranchOfService bos 
			ON bos.ID = ad.BranchOfServiceID
			
		LEFT JOIN dbo.Letter_DATA ld 
			ON com.LetterId = ld.ID
			
		LEFT JOIN CTE cte ON p.ID = cte.PersonID			
			
		OUTER APPLY (SELECT CASE WHEN inq.DMDCValidationDate IS NULL THEN inq.InquiryDate ELSE inq.DMDCValidationDate END AS DMDCValidationDate 
					FROM dbo.Inquiry inq 
						INNER JOIN dbo.Task task 
							ON inq.ID  = task.InquiryID 
						WHERE inq.InquiryType = 'dmdc_check' AND task.ID = com.TaskId) dmdc
						
ORDER BY COALESCE(cast(cte.DateOfContact as date), 
					CASE WHEN cast(p.[Timestamp] as date) = '2019-02-15' THEN NULL ELSE cast(p.[timestamp] as date) END) DESC			

/*
EXEC [dbo].[spServiceMember_Expired_Denied_Active_Report]
*/

--PRINT char(34) + char(9) + ''''''