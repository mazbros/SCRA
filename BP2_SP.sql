USE [SCRA_DB_TEST_43_1]
GO
/****** Object:  StoredProcedure [dbo].[spBenefitPopulation_2_Report]    Script Date: 11/12/2019 12:34:12 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =======================================================
-- Author:		<Aleksey Mazur>
-- Create date: <10/29/2019>
-- Description:	<Benefit population Report with parameters>
-- ========================================================
CREATE PROCEDURE [dbo].[spBenefitPopulation_2_Report] 
	@Period varchar(10),
	@Year varchar(4),
	@Month varchar(2)	
WITH RECOMPILE
AS
BEGIN
	SET NOCOUNT ON;
	
	DECLARE 
        @ErrorNumber    INT,
        @ErrorMessage   VARCHAR(2048),
        @ErrorSeverity  INT,
        @ErrorLine  INT,
        @ErrorSource    SYSNAME,
        @ErrorState INT;        

	BEGIN

		BEGIN TRY

			BEGIN TRANSACTION 
			
				DECLARE @DateStart date, @DateEnd date
				
				IF @Period = 'all' BEGIN
					SET @DateStart = '01/01/'+@Year
					SET @DateEnd = CAST(getdate() as DATE)
				END
				IF @Period = 'year' BEGIN
					SET @DateStart = CAST('01/01/'+@Year  as DATE)
					SET @DateEnd = CAST('12/31/'+@Year  as DATE)
				END
				IF @Period = 'month' BEGIN
					SET @DateStart = @Month+'/01/'+@Year
					SET @DateEnd = dbo.fnLastDayOfMonth(@DateStart)
				END
				
				DECLARE @SQL varchar(max)

				SET @SQL = '		
				SELECT DISTINCT b.BenefitIntervalId
					,cast(i.InquiryDate as DATE) as ContactDate
					,CASE ISNULL(i.IdentificationMethod,'''') 
						WHEN ''internal'' THEN ''Proactive''
						WHEN ''line_business'' THEN ''Line of Business''
						WHEN ''customer'' THEN ''Customer Originated''
						WHEN '''' THEN ''''
						ELSE ''''
					END as IdentificationMethod
					
					,b.PersonID as SMID,sm.FNumber,smn.FirstName as SMFirstName,smn.MiddleInitial as SMMiddleInitial,smn.LastName as SMLastName
					,adr.Branch,adr.Reserv
					,CONVERT(VARCHAR(10),adr.ADSD,121) as ADSD
					,CASE WHEN CONVERT(varchar(10),adr.ADED,121) = ''9999-12-31'' AND ISNULL(adr.ADSD,'''') <> '''' THEN ''PRESENT'' ELSE CASE WHEN ISNULL(adr.ADSD,'''') <> '''' THEN CONVERT(VARCHAR(10),adr.ADED,121) ELSE NULL END END as ADED 
					,adr.ADCount 
					
					,UPPER(SUBSTRING(b.[Status],1,1))+SUBSTRING(b.[Status],2,LEN(b.[Status]) - 1) as [Status],bd.BenefitAppliedDate,bd.BenefitEffectiveDate,bd.ExpectedRemovalDate,bd.BenefitRemovedDate 
					
					,c.PersonID as CustID,cust.FNumber as CustFNumber,p.FirstName as CustFirstName,p.MiddleInitial as CustMiddleInitial,p.LastName as CustLastName
					
					,dbo.PARTENON_Format(c.ContractNo) as ContractNo
					,CASE WHEN ISNULL(c.LegacyNo,'') = '' THEN dbo.CardNo_Format(c.CardNo) ELSE dbo.LegacyNo_Format(c.LegacyNo) END as AccountNo
					,dbo.fnProductName(c.ContractTypeId) as ProductType
					,CASE WHEN ISNULL(c.ProductName,'') <> '' THEN c.ProductName ELSE dbo.fnProductSubName(c.ContractTypeId) END as ProductSubType
					,c.OpenDate as ProductOpenDate,c.CloseDate as ProductCloseDate
					
				FROM [Benefit] b 
						JOIN [BenefitDetail] bd ON b.ID = bd.BenefitID 
							JOIN [Contract] c ON (b.ContractID = c.ID)
								JOIN [Person] p ON c.PersonID = p.ID
									JOIN [Task] t on b.TaskID = t.ID
										JOIN Inquiry i on t.InquiryID = i.ID
											JOIN 
												(SELECT b.BenefitIntervalId ,MIN(ad.StartDate) as ADSD,MAX(ISNULL(ad.EndDate,''9999-12-31'')) as ADED,ad.PersonID, COUNT(b.ActiveDutyID) as ADCount, 
													   MAX(dbo.fnServiceBranchByID(ad.BranchOfServiceID)) as Branch, MAX(dbo.fnIsReservistByBranchID(ad.BranchOfServiceID)) as Reserv 
												FROM ActiveDuty ad JOIN Benefit b on b.ActiveDutyID = ad.ID WHERE b.BenefitIntervalId IS NOT NULL GROUP BY b.BenefitIntervalID,ad.PersonID) adr
												ON adr.BenefitIntervalId = b.BenefitIntervalId
												JOIN [Customer] cust on cust.PersonID = c.PersonID
													JOIN [Customer] sm on   sm.PersonID = adr.PersonID
														JOIN Person smn on smn.ID = adr.PersonID
																WHERE b.BenefitIntervalId
						IN		
						(
						SELECT b.BenefitIntervalId
						FROM [Benefit] b 
							JOIN [Task] t on b.TaskID = t.ID
							JOIN [BenefitDetail] bd ON b.ID = bd.BenefitID
						WHERE 1 = 1
							AND ISNULL(t.[Status],'''') <> ''misdirected''
							AND t.TaskType = ''add_benefit'' '
							
							IF @Period <> 'all' BEGIN
							SET @SQL = @SQL + '
							AND (ISNULL(bd.BenefitAppliedDate,'''') < ''' + CAST(@DateStart as varchar(10)) + ''' OR ISNULL(bd.BenefitEffectiveDate,'''') < ''' + CAST(@DateStart as varchar(10)) + ''' OR bd.BenefitAppliedDate IS NULL)'
							END
							SET @SQL = @SQL + '
							AND b.BenefitIntervalId NOT IN (	
								SELECT b.BenefitIntervalId
									FROM [Benefit] b 
										JOIN [Task] t on b.TaskID = t.ID
										JOIN [BenefitDetail] bd ON b.ID = bd.BenefitID
									WHERE 1 = 1
										AND ISNULL(t.[Status],'''') <> ''misdirected''
										AND t.TaskType = ''remove_benefit'' 
										AND (ISNULL(bd.BenefitRemovedDate,'''') < ''' + CAST(@DateStart as varchar(10)) + ''' OR bd.BenefitRemovedDate IS NULL)
										GROUP BY b.BenefitIntervalId
									)
						GROUP BY b.BenefitIntervalId
						)
						AND TaskType = ''add_benefit'' 
						AND ISNULL(t.[Status],'''') <> ''misdirected''
						AND c.IsDeleted = 0
						AND (ISNULL(bd.BenefitRemovedDate,'''') > ''' + CAST(@DateEnd as varchar(10)) + ''' or bd.BenefitRemovedDate IS NULL)
						
				ORDER BY b.PersonID'
			
				PRINT @SQL
				EXEC (@SQL)				
				
			COMMIT TRANSACTION
    
		END TRY
		BEGIN CATCH
			ROLLBACK TRANSACTION        
			SET @ErrorMessage = ERROR_MESSAGE();
			SET @ErrorSource  = ISNULL(ERROR_PROCEDURE(), 'Unknown');
			SET @ErrorLine    = ERROR_LINE();
			SET @ErrorSeverity= ERROR_SEVERITY();
			SET @ErrorState   = ERROR_STATE();
			GOTO ErrorHandler;
		END CATCH
		RETURN;
    
		ErrorHandler:
			RAISERROR('The following error has occured in the object [%s]: Error Number %d on line %d with message [%s]',
						@ErrorSeverity, @ErrorState, @ErrorSource, @ErrorNumber, @ErrorLine, @ErrorMessage)  

	END			

END

/*

EXEC [dbo].[spBenefitPopulation_2_Report] @Period='month',@Year='2019',@Month='09'

*/
GO
