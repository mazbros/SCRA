USE [SCRA_DB]
GO
/****** Object:  StoredProcedure [dbo].[spServicemember_Expired_Denied_Active_Report_2]    Script Date: 08/26/2019 16:15:26 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ================================================
-- Author:		<Aleksey Mazur>
-- Create date: <08/26/2019>
-- Description:	<Servicemember Active Duty Report>
-- ================================================
CREATE PROCEDURE [dbo].[spServicemember_Expired_Denied_Active_Report_2]
WITH RECOMPILE
AS
BEGIN
	SET NOCOUNT ON;

;WITH TBL AS (
SELECT DISTINCT 
	   CAST(i.InquiryDate as DATE)													as ContactDate
	  ,CAST(mh.DateOfContact as DATE)												as MigratedDateOfContact
      ,CAST(COALESCE(i.InquiryDate,mh.DateOfContact,NULL) as date)					as DateOfContact
	  ,CAST(st.CompletionDate as DATE)												as LogDate
	  ,i.ContactMethodID															as InquiryContactMethod
	  ,pa.[ContactMethodID]															as ServicememberContactMethod
	  ,pc.[ContactMethodID]															as CustomerContactMethod
	  ,mh.MethodOfNotification							    						as MigratedContactMethod
	  ,COALESCE(dbo.fnResponseMethodName(i.ContactMethodID)
				,dbo.fnResponseMethodName(pa.[ContactMethodID])
				,dbo.fnResponseMethodName(pc.[ContactMethodID])
				,mh.MethodOfNotification,'Proactive',NULL)							as OriginalContactMethod
	  ,''																			as DateDMDCSearchPerformed
	  ,ISNULL(mh.VerifyBySCRAOrMilOrders,'')										as VerifyBySCRAOrMilOrders
	  ,CAST(COALESCE(ad.NoticeDate,mh.[Notification Date]) as DATE)					as DateMilitaryOrdersReceived
	  ,dbo.fnGetUserName(t.AssigneeID)												as Agent
	  ,dbo.fnGetUserName(t.QaAssigneeId)											as QCAgent
	  ,t.[Status]																	as TaskStatus
	  ,b.[Status]																	as BenefitApprovedDeniedPending
	  ,COALESCE(CASE WHEN b.[Status] = 'Denied' THEN 'Not Eligible'
		    WHEN b.[Status] IN 
				('applying','applied','removing','removed','extending','extended') 
					THEN 'Active Duty' 
			ELSE NULL END,mh.StatusCode)											as StatusCode
	  ,b.DenialReason																as NotEligReason
	  ,b.DenialReason																as DenialReason
	  ,pa.[ID]																		as ServicememberID
      ,pa.[LastName]																as ServicememberLastName
      ,pa.[FirstName]																as ServicememberFirstName
      ,pa.[MiddleInitial]															as ServicememberMiddleInitial
      ,ISNULL(CONVERT(VARCHAR(10),pa.DOB,101),'')									as ServicememberDOB
      ,custa.FNumber																as ServicememberFNumber
      ,dbo.SSN_Format(pa.SSN)														as ServicememberSocialSecurityNumber
	  ,dbo.fnServiceBranchByID(ad.BranchOfServiceID)								as BranchOfService
	  ,ad.Startdate																	as ADStartDate
      ,ad.EndDate																	as ADEndDate
      ,ad.NoticeDate																as NoticeDate
      ,dbo.fnIsReservistByBranchID(ad.BranchOfServiceID)							as Reserv
      ,CASE WHEN b.[Status] IN ('applied','applying','extending','extended') 
			THEN bd.BenefitAppliedDate ELSE NULL END								as DateBenefitsApplied
	  ,bd.ExpectedRemovalDate														as ExpectedRemovalDate		
	  ,CASE WHEN b.[Status] IN ('removed','removing') 
			THEN bd.BenefitRemovedDate ELSE NULL END								as DateBenefitsEnded
	  ,bd.BenefitEffectiveDate														as BenefitsEffectiveDate	
      
      ,pc.ID																		as CustomerID
      ,pc.LastName																	as CustomerLastName
      ,pc.FirstName																	as CustomerFirstName
      ,pc.MiddleInitial																as CustomerMiddleInitial
      ,ISNULL(CONVERT(VARCHAR(10),pc.DOB,101),'')									as CustomerDOB
      ,custc.FNumber																as CustomerFNumber
      ,dbo.SSN_Format(pc.SSN)														as CustomerSocialSecurityNumber
      
	  ,dbo.fnProductName(c.ContractTypeId)											as ProductType
      ,dbo.fnProductSubName(c.ContractTypeId,pc.ID)									as SubType	
      ,COALESCE(
			CASE 
				WHEN ISNULL(c.LegacyNo,'') = '' 
				THEN NULL 
				ELSE dbo.LegacyNo_Format(c.LegacyNo) END,
			CASE 
				WHEN ISNULL(c.CardNo,'') = '' 
				THEN NULL 
				ELSE dbo.CardNo_Format(c.CardNo) END,
			CASE 
				WHEN ISNULL(c.ContractNo,'') = '' 
				THEN NULL 
				ELSE dbo.PARTENON_Format(c.ContractNo) END)							as AccountNum
		,c.OpenDate																	as StartDate
		,c.CloseDate																as EndDate
		,COALESCE(CASE WHEN ISNULL(b.DenialReason	,'') <> '' 
					THEN 'No' 
					ELSE 
						CASE WHEN b.[Status] IN ('applying','applied','removing','removed','extending','extended') 
							THEN 'Yes' ELSE 'No' END END,
					CASE WHEN mh.ActiveAccountEligible = 0 THEN 'No'
					   WHEN mh.ActiveAccountEligible = 1 THEN 'Yes'
					   ELSE NULL END)
																					as ActiveAccountEligible
      ,pa.[Address1]																as Address1
      ,pa.[Address2]																as Address2
      ,pa.[City]																		as City
      ,pa.[State]																	as [State]
      ,CASE WHEN LEN(REPLACE(CONVERT(VARCHAR(10),pa.Zip),'-','')) = 9
				THEN LEFT(REPLACE(CONVERT(VARCHAR(10),pa.Zip),'-',''),5)
					+'-'+RIGHT(REPLACE(CONVERT(VARCHAR(10),pa.Zip),'-',''),4)
			  WHEN LEN(REPLACE(CONVERT(VARCHAR(10),pa.Zip),'-','')) = 5
				THEN REPLACE(CONVERT(VARCHAR(10),pa.Zip),'-','')+'-0000'
			  WHEN pa.Zip = '00000' OR pa.Zip = '00000-0000' OR pa.Zip = '000000000'
				THEN ''
			ELSE ''
		 END																		as Zip
      ,pa.Email																		as Email
	  ,pa.[Phone]																	as Phone
      ,COALESCE(CASE WHEN ISNULL(b.DenialReason	,'') <> '' 
					THEN 'No' 
					ELSE 
						CASE WHEN b.[Status] 
								IN ('applying','applied','removing','removed','extending','extended') 
							THEN 'Yes' ELSE 'No' END END,
				  CASE WHEN mh.BenefitsRecvd = 0 THEN 'No'
					   WHEN mh.BenefitsRecvd = 1 THEN 'Yes'
					   ELSE NULL END)												as BenefitsRecvd  
      ,bd.CurrentRate																as [Interest Rate before SCRA]
	  ,CASE WHEN bd.IsInterestAdjustmentCalculated = 0 THEN 'No'
			WHEN bd.IsInterestAdjustmentCalculated = 1 THEN 'Yes'	
		    ELSE NULL END															as [Interest Adjustment]
	  ,bd.PromotionEndDate															as [Promo Rate End Date] 
	  ,bd.InterestRefunded															as RefundAmount
	  ,bd.InterestRefundedDate														as RefundDate
	  ,REPLACE(REPLACE(STUFF((SELECT ','+note.Comment 
			FROM dbo.Note note WHERE PersonID = pa.ID 
			ORDER BY note.[Timestamp] DESC FOR XML PATH('')),1,1,''),','
			,CHAR(13)+CHAR(10)+CHAR(13)+CHAR(10)),CHAR(34),CHAR(39)+CHAR(39))       as Comments
      ,''																		    as AdditionalComments
     
      ,com.ID																	    as CommunicationID
	  ,cast(com.CommunicationDate as DATE)										    as DateSent
	  ,CASE WHEN CONVERT(VARCHAR(3),ISNULL(com.LetterId,'')) = 0 
		THEN '' ELSE CONVERT(VARCHAR(3),ISNULL(com.LetterId,'')) END			    as LetterId
	  ,''																			as Returned
	  ,RIGHT(COALESCE(CASE WHEN ISNULL(c.LegacyNo,'') = '' THEN NULL 
				ELSE CASE 
					WHEN RIGHT(c.LegacyNo,3) = '001' AND LEN(c.Legacyno) > 19
						THEN SUBSTRING(c.LegacyNo,1,LEN(c.LegacyNo)-3) 
					ELSE c.LegacyNo END END,
					CASE WHEN ISNULL(c.CardNo,'') = '' 
						THEN NULL ELSE c.CardNo END,mh.Account),4)					as Account
	  ,CASE WHEN CONVERT(VARCHAR(3),ISNULL(com.LetterId,'')) = 0 
				THEN '' ELSE ISNULL(ld.LetterCode,'') END							as LetterCode						
	  ,ISNULL(ld.LetterName,'')														as LetterName
	  ,ISNULL(ld.LetterLongDesc,'')													as LetterFullName
	  
	  ,b.ID																			as BenefitID_Benefit
	  ,com.BenefitID																as BenefitID_Comm
	  ,b.ContractID																	as ContractID_Benefit
	  ,c.ID																			as ContractID
	  ,b.ActiveDutyID																as ActiveDutyID_Benefit
	  ,ad.ID																		as ActiveDutyID
	  ,com.CommunicationDate														AS CommunicationDate
	  ,i.InquiryType																as InquiryType
	  ,b.TaskID																		as Benefit_TaskID
	  ,pa.Origin																	as ServicememberOrigin
	  ,pc.Origin																	as CustomerOrigin
      ,t.TaskType																	as TaskType
      
  FROM Benefit b
			LEFT JOIN [Contract] c ON ISNULL(b.ContractID,'') = c.ID AND c.IsDeleted = 0
				LEFT JOIN Person pc ON (ISNULL(c.PersonID,'') = pc.ID OR ISNULL(b.PersonID,'') = pc.ID)
					LEFT JOIN Customer custc ON ISNULL(c.PersonID,'') = ISNULL(custc.PersonID,'')
						LEFT JOIN ActiveDuty ad ON ISNULL(b.ActiveDutyID,'') = ISNULL(ad.ID,'')
							LEFT JOIN Customer custa ON ISNULL(ad.PersonID,'') = ISNULL(custa.PersonID,'')
								LEFT JOIN Person pa ON ISNULL(b.PersonID,'') = ISNULL(pa.ID,'') OR ISNULL(ad.PersonID,'') = ISNULL(pa.ID,'')
									LEFT JOIN Task t ON ISNULL(b.TaskId,'') = ISNULL(t.ID,'')
										LEFT JOIN BenefitDetail bd ON b.ID = bd.BenefitID
											LEFT JOIN Inquiry i on ISNULL(t.InquiryID,'') = ISNULL(i.ID,'')
												LEFT JOIN Communication com ON b.ID = ISNULL(com.BenefitId,'')
													LEFT JOIN Letter_DATA ld ON com.LetterId = ld.ID
														LEFT JOIN (SELECT CompletionDate,TaskId FROM SubTask st WHERE st.SortNo = 1) st ON ISNULL(st.TaskID,'') = t.ID
															LEFT JOIN Servicemember sm ON pa.ID = sm.PersonID OR pc.ID = sm.PersonID
																LEFT JOIN Migration_History mh ON mh.ServiceMemberID = sm.ServicememberID
						
WHERE 1=1
	AND ISNULL(t.TaskType,'') <> 'contact_customer'
	AND ISNULL(t.[Status],'') <> 'misdirected'
	AND pa.ID = ad.PersonID
)

SELECT * INTO #Temp FROM TBL
SELECT tt.*
FROM #Temp tt 
ORDER BY ServicememberID


DROP TABLE #Temp

END
GO
/****** Object:  StoredProcedure [dbo].[spServicemember_Active_Duty_Report]    Script Date: 08/26/2019 16:15:26 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ===================================================================
-- Author:		<Aleksey Mazur>
-- Create date: <08/15/2019>
-- Description:	<Servicemember_Active_Duty_Report_Prototype>
-- ===================================================================
CREATE PROCEDURE [dbo].[spServicemember_Active_Duty_Report] 
WITH RECOMPILE
AS
BEGIN
	SET NOCOUNT ON;

SELECT DISTINCT * FROM (
SELECT 
	   COALESCE(pa.ID,bcp.ServicememberID)										as ServicememberID
	  ,COALESCE(pa.LastName,bcp.ServicememberLastName)							as ServicememberLastName
	  ,COALESCE(pa.FirstName,bcp.ServicememberFirstName)						as ServicememberFirstName
	  ,COALESCE(custa.FNumber,bcp.ServiceMemberFnumber)							as ServicememberFNumber
	  ,COALESCE(pa.Origin,bcp.ServicememberOrigin)								as ServicememberOrigin
	  
	  ,COALESCE(ad.ID,bcp.ActiveDutyId)											as ActiveDutyId
	  ,COALESCE(dbo.fnServiceBranchByID(ad.BranchOfServiceID)
				,dbo.fnServiceBranchByID(bcp.BranchOfServiceID))				as BranchOfService
	  ,COALESCE(ad.StartDate,bcp.ActiveDutyStartDate)							as ADStartDate
	  ,COALESCE(ad.EndDate,bcp.ActiveDutyEndDate)								as ADEndDate
	  ,COALESCE(ad.NoticeDate,bcp.NoticeDate)									as NoticeDate
	  ,COALESCE(dbo.fnIsReservistByBranchID(ad.BranchOfServiceID)
				,dbo.fnIsReservistByBranchID(bcp.BranchOfServiceID))			as Reserv
	   
	  ,bcp.CustomerID															as CustomerID
	  ,bcp.CustomerLastName														as CustomerLastName
	  ,bcp.CustomerFirstName													as CustomerFirstName
	  ,bcp.CustomerFNumber														as CustomerFNumber
	  ,bcp.CustomerOrigin														as CustomerOrigin
	  
	  ,bcp.ContractId															as ContractID
	  ,bcp.ProductType															as Product
	  ,bcp.SubType																as SubProduct
	  ,bcp.OpenDate																as OpenDate
	  ,bcp.CloseDate															as CloseDate
	  ,bcp.ContractNo															as ContractNo
	  ,bcp.AccountNum															as AccountNum
      
      ,bcp.TaskStatus															as TaskStatus
      ,bcp.TaskType																as TaskType
	  
	  ,bcp.BenefitId															as BenefitId
	  ,bcp.BenefitStatus														as BenefitStatus 
	  ,bcp.BenefitAppliedDate
	  ,bcp.ExpectedRemovalDate
	  ,bcp.BenefitRemovedDate
	  ,bcp.DenialReason
	  
	  ,REPLACE(REPLACE(STUFF((SELECT ','+note.Comment 
			FROM dbo.Note note WHERE PersonID = pa.ID 
			ORDER BY note.[Timestamp] DESC FOR XML PATH('')),1,1,''),','
			,CHAR(13)+CHAR(10)+CHAR(13)+CHAR(10)),CHAR(34),CHAR(39)+CHAR(39))       as Comments

FROM [Person] pa 
	LEFT JOIN [ActiveDuty] ad ON ISNULL(pa.ID,'') = ISNULL(ad.PersonID,'')
		LEFT JOIN [Customer] custa ON ISNULL(ad.PersonID,'') = ISNULL(custa.PersonID,'') 
	
	LEFT JOIN [Contract] c ON ISNULL(pa.ID,'') = ISNULL(c.PersonID,'') AND c.IsDeleted = 0
	
	LEFT JOIN [Person] pc ON ISNULL(c.PersonID,'') =  ISNULL(pc.ID,'')
		
	LEFT JOIN [Benefit] b 
		ON (
			  pa.ID = ISNULL(b.PersonID,'') AND ISNULL(ad.ID,'') = ISNULL(b.ActiveDutyID,'')  AND	ISNULL(c.ID,'') = ISNULL(b.ContractID,'')
			OR
			  pc.ID = ISNULL(b.PersonID,'') AND	ISNULL(c.ID,'') = ISNULL(b.ContractID,'')
			)
	LEFT JOIN [BenefitDetail] bd ON ISNULL(b.ID,'') = ISNULL(bd.BenefitID,'')

	LEFT JOIN [Task] t ON ISNULL(b.TaskID,'') = ISNULL(t.ID,'')
	
	LEFT OUTER JOIN (
	Select B.ID											As BenefitId
        , ISNULL(BD.ID, 0)								As BenefitDetailId
		, B.ActiveDutyId								As ActiveDutyId
		, p_AD.ID										As ServicememberID
		, P_AD.FirstName								As ServicememberFirstName
		, P_AD.LastName									As ServicememberLastName
		, CUS_SM.FNumber								As ServicememberFnumber
		, P_AD.Origin									As ServicememberOrigin
		, C.ID											As ContractId
		, P_C.ID										As CustomerID
		, P_C.FirstName									As CustomerFirstName
		, P_C.LastName									As CustomerLastName
		, p_C.Origin									As CustomerOrigin
		, CUS.FNumber									As CustomerFnumber
		, B.TaskId										As TaskId
		, I.ID											As InquiryId
		, T_Inquiry.ID									As InquiryTaskId
		, T_Inquiry.TaskType							As InquiryTaskType
		, B.[Status]									As BenefitStatus
		, BD.BenefitAppliedDate							As BenefitAppliedDate
        , BD.ExpectedRemovalDate						As ExpectedRemovalDate
		, BD.BenefitRemovedDate							As BenefitRemovedDate
		, BD.BenefitEffectiveDate						As BenefitEffectiveDate
		, B.DenialReason								As DenialReason
		, A.BranchOfServiceID							As BranchOfServiceId
		, A.StartDate									As ActiveDutyStartDate
		, A.EndDate										As ActiveDutyEndDate
		, A.NoticeDate									As NoticeDate
        , dbo.PARTENON_Format(C.ContractNo)				As ContractNo
        , dbo.fnProductName(c.ContractTypeId) 			As ProductType
        , dbo.fnProductSubName(c.ContractTypeId,P_C.ID)	As SubType
		, COALESCE(
			CASE 
				WHEN ISNULL(C.LegacyNo,'') = '' 
				THEN NULL 
				ELSE dbo.LegacyNo_Format(C.LegacyNo) END,
			CASE 
				WHEN ISNULL(C.CardNo,'') = '' 
				THEN NULL 
				ELSE dbo.CardNo_Format(C.CardNo) END)  As AccountNum
		, C.OpenDate
		, C.CloseDate
		, T.TaskType
        , T.[Status]									As TaskStatus
		, I.InquiryDate

	from Benefit As B
	RIGHT join Contract C On B.ContractID = C.ID
	LEFT join Person P_C On P_C.ID = C.PersonID 
	LEFT join Customer CUS On CUS.PersonID = P_C.ID
	left join ActiveDuty As A On A.ID = B.ActiveDutyId
	left join Person P_AD On P_AD.ID = A.PersonID
	left join Customer CUS_SM On CUS_SM.PersonID = P_AD.ID 
	left join Task T On B.TaskID = T.ID
    left join BenefitDetail BD On BD.BenefitId = B.ID
	left join Inquiry I On I.ID = T.InquiryID
	left join Task T_Inquiry On T_Inquiry.InquiryID = I.ID 
	Where  (C.PersonID in (Select P.ID As PersonId
									from Person P
									where P.ID  in (Select ToID from PersonToPersonLink where FromID = P.ID) OR P.ID  in (Select FromID from PersonToPersonLink where ToID = P.ID) OR P.ID = P.ID
								) and C.IsDeleted = 0)
								) bcp ON pa.ID = bcp.ServicememberID OR pc.ID = bcp.CustomerID
	
WHERE 1 = 1 AND pa.Origin NOT IN ('dmdc_check','inquiry') OR pc.Origin NOT IN ('dmdc_check','inquiry')
) th
WHERE 1=1 AND ISNULL(TaskStatus,'') <> 'misdirected' 
AND ServicememberID <> 1804
ORDER BY ServicememberID,ADStartDate,OpenDate,CloseDate DESC
	
END

/*
EXEC [dbo].[spServicemember_Active_Duty_Report]
*/
GO
