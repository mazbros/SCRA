USE [SCRA_DB]
GO
/****** Object:  StoredProcedure [dbo].[spCurrentlyReceivingBenefits_Report]    Script Date: 12/26/2019 14:56:36 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =================================================================
-- Author:		<Aleksey Mazur>
-- Create date: <12/26/2019>
-- Description:	<Curently Receiving Benefits Report with parameters>
-- =================================================================
CREATE PROCEDURE [dbo].[spCurrentlyReceivingBenefits_Report] 
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
				
				IF LEN(@Year) = 0 BEGIN SET @Year = (SELECT CAST(YEAR(GETDATE()) AS VARCHAR(4))) END
				
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
					,CASE WHEN CONVERT(varchar(10),adr.ADED,121) = ''9999-12-31'' AND ISNULL(adr.ADSD,'''') <> '''' THEN '''' ELSE CASE WHEN ISNULL(adr.ADSD,'''') <> '''' THEN CONVERT(VARCHAR(10),adr.ADED,121) ELSE NULL END END as ADED 
					,adr.ADCount 
					
					,CASE WHEN ISNULL(b.[Status],'''') != '''' THEN UPPER(SUBSTRING(b.[Status],1,1))+SUBSTRING(b.[Status],2,LEN(b.[Status]) - 1) ELSE '''' END as [Status]
					,bd.BenefitAppliedDate,bd.BenefitEffectiveDate,bd.ExpectedRemovalDate,bd.BenefitRemovedDate 
					
					,c.PersonID as CustID,cust.FNumber as CustFNumber,p.FirstName as CustFirstName,p.MiddleInitial as CustMiddleInitial,p.LastName as CustLastName
					
					,dbo.PARTENON_Format(c.ContractNo) as ContractNo
					,CASE WHEN ISNULL(c.LegacyNo,'''') = '''' THEN dbo.CardNo_Format(c.CardNo) ELSE dbo.LegacyNo_Format(c.LegacyNo) END as AccountNo
					,dbo.fnProductName(c.ContractTypeId) as ProductType
					,dbo.fnProductSubName(c.ID) as ProductSubType
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
						SELECT ISNULL(b.BenefitIntervalId,0)
						FROM [Benefit] b 
							JOIN [Task] t on b.TaskID = t.ID
							JOIN [BenefitDetail] bd ON b.ID = bd.BenefitID
						WHERE 1 = 1
							AND ISNULL(t.[Status],'''') <> ''misdirected''
							AND (t.TaskType = ''add_benefit'' OR t.TaskType = ''extend_benefit'' OR t.TaskType = ''continue_benefit'') '
							
							IF @Period = 'all' BEGIN
								SET @SQL = @SQL + '
								AND (ISNULL(bd.BenefitAppliedDate,'''') < ''' + CAST(@DateEnd as VARCHAR(10)) + ''' OR bd.BenefitAppliedDate IS NULL)'
							END 
							IF @Period = 'month' BEGIN
								SET @SQL = @SQL + '
								AND (ISNULL(bd.BenefitAppliedDate,'''') <= ''' + CAST(@DateEnd as varchar(10)) + ''' OR bd.BenefitAppliedDate IS NULL)'
							END
							IF @Period = 'year' BEGIN
								SET @SQL = @SQL + '
								AND (ISNULL(bd.BenefitAppliedDate,'''') <= ''' + CAST(@DateEnd as varchar(10)) + ''' OR bd.BenefitAppliedDate IS NULL)'
							END
							SET @SQL = @SQL + '
							AND b.BenefitIntervalId NOT IN (	
								SELECT ISNULL(b.BenefitIntervalId,0)
									FROM [Benefit] b 
										JOIN [Task] t on b.TaskID = t.ID
										JOIN [BenefitDetail] bd ON b.ID = bd.BenefitID
									WHERE 1 = 1
										AND ISNULL(t.[Status],'''') <> ''misdirected''
										AND t.TaskType = ''remove_benefit'' '
							IF @Period = 'all' BEGIN
								SET @SQL = @SQL + '
										AND (ISNULL(bd.BenefitRemovedDate,'''') < ''' + CAST(@DateEnd as varchar(10)) + ''' OR bd.BenefitRemovedDate IS NULL) '
							END 
							IF @Period = 'month' BEGIN
								SET @SQL = @SQL + '
										AND (ISNULL(bd.BenefitRemovedDate,'''') < ''' + CAST(@DateStart as varchar(10)) + ''' OR bd.BenefitRemovedDate IS NULL) '
							END
							IF @Period = 'year' BEGIN
								SET @SQL = @SQL + '
										AND (ISNULL(bd.BenefitRemovedDate,'''') < ''' + CAST(@DateEnd as varchar(10)) + ''' OR bd.BenefitRemovedDate IS NULL) '
							END
							SET @SQL = @SQL + '
										GROUP BY b.BenefitIntervalId
									)
						GROUP BY b.BenefitIntervalId
						)
						AND (TaskType = ''add_benefit'' OR TaskType = ''extend_benefit'' OR TaskType = ''continue_benefit'')
						AND ISNULL(t.[Status],'''') <> ''misdirected''
						AND c.IsDeleted = 0 
						AND (ISNULL(c.CloseDate,'''') > ''' + CAST(@DateEnd as varchar(10)) + ''' or c.CloseDate IS NULL) '
						IF @Period = 'all' BEGIN
								SET @SQL = @SQL + '
						AND (ISNULL(bd.BenefitRemovedDate,'''') > ''' + CAST(@DateEnd as varchar(10)) + ''' OR bd.BenefitRemovedDate IS NULL) '
						END 
						IF @Period = 'year' BEGIN
								SET @SQL = @SQL + '
						AND (ISNULL(bd.BenefitRemovedDate,'''') > ''' + CAST(@DateEnd as varchar(10)) + ''' OR bd.BenefitRemovedDate IS NULL) '
						END
						IF @Period = 'month' BEGIN
								SET @SQL = @SQL + '
						AND (ISNULL(bd.BenefitRemovedDate,'''') > ''' + CAST(@DateEnd as varchar(10)) + ''' OR bd.BenefitRemovedDate IS NULL) '
						END
						SET @SQL = @SQL + '
												
				ORDER BY b.PersonID,bd.BenefitAppliedDate'
			
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

EXEC [dbo].[spCurrentlyReceivingBenefits_Report] @Period='all',@Year='',@Month=''

*/
GO
/****** Object:  StoredProcedure [dbo].[spOpenActiveBenefits_Report]    Script Date: 12/26/2019 14:56:36 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =========================================================
-- Author:		<Aleksey Mazur>
-- Create date: <12/26/2019>
-- Description:	<Open Active Benefits Report with parameters>
-- ==========================================================
CREATE PROCEDURE [dbo].[spOpenActiveBenefits_Report] 
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
				
				IF LEN(@Year) = 0 BEGIN SET @Year = (SELECT CAST(YEAR(GETDATE()) AS VARCHAR(4))) END
				
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
					,CASE WHEN CONVERT(varchar(10),adr.ADED,121) = ''9999-12-31'' AND ISNULL(adr.ADSD,'''') <> '''' THEN '''' ELSE CASE WHEN ISNULL(adr.ADSD,'''') <> '''' THEN CONVERT(VARCHAR(10),adr.ADED,121) ELSE NULL END END as ADED 
					,adr.ADCount 
					
					,CASE WHEN ISNULL(b.[Status],'''') != '''' THEN UPPER(SUBSTRING(b.[Status],1,1))+SUBSTRING(b.[Status],2,LEN(b.[Status]) - 1) ELSE '''' END as [Status]
					,bd.BenefitAppliedDate,bd.BenefitEffectiveDate,bd.ExpectedRemovalDate,bd.BenefitRemovedDate 
					
					,c.PersonID as CustID,cust.FNumber as CustFNumber,p.FirstName as CustFirstName,p.MiddleInitial as CustMiddleInitial,p.LastName as CustLastName
					
					,dbo.PARTENON_Format(c.ContractNo) as ContractNo
					,CASE WHEN ISNULL(c.LegacyNo,'''') = '''' THEN dbo.CardNo_Format(c.CardNo) ELSE dbo.LegacyNo_Format(c.LegacyNo) END as AccountNo
					,dbo.fnProductName(c.ContractTypeId) as ProductType
					,dbo.fnProductSubName(c.ID) as ProductSubType
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
						SELECT ISNULL(b.BenefitIntervalId,0)
						FROM [Benefit] b 
							JOIN [Task] t on b.TaskID = t.ID
							JOIN [BenefitDetail] bd ON b.ID = bd.BenefitID
						WHERE 1 = 1
							AND ISNULL(t.[Status],'''') <> ''misdirected''
							AND (t.TaskType = ''add_benefit'' OR t.TaskType = ''extend_benefit'' OR t.TaskType = ''continue_benefit'') '
							
							IF @Period = 'all' BEGIN
								SET @SQL = @SQL + '
								AND (ISNULL(bd.BenefitAppliedDate,'''') < ''' + CAST(@DateEnd as VARCHAR(10)) + ''' OR bd.BenefitAppliedDate IS NULL)'
							END 
							IF @Period = 'month' BEGIN
								SET @SQL = @SQL + '
								AND (ISNULL(bd.BenefitAppliedDate,'''') < ''' + CAST(@DateStart as varchar(10)) + ''' OR bd.BenefitAppliedDate IS NULL)'
							END
							IF @Period = 'year' BEGIN
								SET @SQL = @SQL + '
								AND (ISNULL(bd.BenefitAppliedDate,'''') <= ''' + CAST(@DateEnd as varchar(10)) + ''' OR bd.BenefitAppliedDate IS NULL)'
							END
							SET @SQL = @SQL + '
							AND b.BenefitIntervalId NOT IN (	
								SELECT ISNULL(b.BenefitIntervalId,0)
									FROM [Benefit] b 
										JOIN [Task] t on b.TaskID = t.ID
										JOIN [BenefitDetail] bd ON b.ID = bd.BenefitID
									WHERE 1 = 1
										AND ISNULL(t.[Status],'''') <> ''misdirected''
										AND t.TaskType = ''remove_benefit'' '
							IF @Period = 'all' BEGIN
								SET @SQL = @SQL + '
										AND (ISNULL(bd.BenefitRemovedDate,'''') < ''' + CAST(@DateEnd as varchar(10)) + ''' OR bd.BenefitRemovedDate IS NULL) '
							END 
							IF @Period = 'month' BEGIN
								SET @SQL = @SQL + '
										AND (ISNULL(bd.BenefitRemovedDate,'''') < ''' + CAST(@DateStart as varchar(10)) + ''' OR bd.BenefitRemovedDate IS NULL) '
							END
							IF @Period = 'year' BEGIN
								SET @SQL = @SQL + '
										AND (ISNULL(bd.BenefitRemovedDate,'''') < ''' + CAST(@DateEnd as varchar(10)) + ''' OR bd.BenefitRemovedDate IS NULL) '
							END
							SET @SQL = @SQL + '
										GROUP BY b.BenefitIntervalId
									)
						GROUP BY b.BenefitIntervalId
						)
						AND (TaskType = ''add_benefit'' OR TaskType = ''extend_benefit'' OR TaskType = ''continue_benefit'')
						AND ISNULL(t.[Status],'''') <> ''misdirected''
						AND c.IsDeleted = 0 
						AND (ISNULL(c.CloseDate,'''') > ''' + CAST(@DateEnd as varchar(10)) + ''' or c.CloseDate IS NULL) '
						IF @Period = 'all' BEGIN
								SET @SQL = @SQL + '
						AND (ISNULL(bd.BenefitRemovedDate,'''') > ''' + CAST(@DateEnd as varchar(10)) + ''' OR bd.BenefitRemovedDate IS NULL) '
						END 
						IF @Period = 'year' BEGIN
								SET @SQL = @SQL + '
						AND (ISNULL(bd.BenefitRemovedDate,'''') > ''' + CAST(@DateEnd as varchar(10)) + ''' OR bd.BenefitRemovedDate IS NULL) '
						END
						IF @Period = 'month' BEGIN
								SET @SQL = @SQL + '
						AND (ISNULL(bd.BenefitRemovedDate,'''') > ''' + CAST(@DateEnd as varchar(10)) + ''' OR bd.BenefitRemovedDate IS NULL) '
						END
						SET @SQL = @SQL + '
												
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

EXEC [dbo].[spOpenActiveBenefits_Report] @Period='all',@Year='',@Month=''

*/
GO
/****** Object:  StoredProcedure [dbo].[spBenefitPopulation_2_Report]    Script Date: 12/26/2019 14:56:36 ******/
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
				
				IF LEN(@Year) = 0 BEGIN SET @Year = (SELECT CAST(YEAR(GETDATE()) AS VARCHAR(4))) END
				
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
					,CASE WHEN CONVERT(varchar(10),adr.ADED,121) = ''9999-12-31'' AND ISNULL(adr.ADSD,'''') <> '''' THEN '''' ELSE CASE WHEN ISNULL(adr.ADSD,'''') <> '''' THEN CONVERT(VARCHAR(10),adr.ADED,121) ELSE NULL END END as ADED 
					,adr.ADCount 
					
					,CASE WHEN ISNULL(b.[Status],'''') != '''' THEN UPPER(SUBSTRING(b.[Status],1,1))+SUBSTRING(b.[Status],2,LEN(b.[Status]) - 1) ELSE '''' END as [Status]
					,bd.BenefitAppliedDate,bd.BenefitEffectiveDate,bd.ExpectedRemovalDate,bd.BenefitRemovedDate 
					
					,c.PersonID as CustID,cust.FNumber as CustFNumber,p.FirstName as CustFirstName,p.MiddleInitial as CustMiddleInitial,p.LastName as CustLastName
					
					,dbo.PARTENON_Format(c.ContractNo) as ContractNo
					,CASE WHEN ISNULL(c.LegacyNo,'''') = '''' THEN dbo.CardNo_Format(c.CardNo) ELSE dbo.LegacyNo_Format(c.LegacyNo) END as AccountNo
					,dbo.fnProductName(c.ContractTypeId) as ProductType
					,dbo.fnProductSubName(c.ID) as ProductSubType
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
						SELECT ISNULL(b.BenefitIntervalId,0)
						FROM [Benefit] b 
							JOIN [Task] t on b.TaskID = t.ID
							JOIN [BenefitDetail] bd ON b.ID = bd.BenefitID
						WHERE 1 = 1
							AND ISNULL(t.[Status],'''') <> ''misdirected''
							AND (t.TaskType = ''add_benefit'' OR t.TaskType = ''extend_benefit'' OR t.TaskType = ''continue_benefit'') '
							
							IF @Period = 'all' BEGIN
								SET @SQL = @SQL + '
								AND (ISNULL(bd.BenefitAppliedDate,'''') < ''' + CAST(@DateEnd as VARCHAR(10)) + ''' OR bd.BenefitAppliedDate IS NULL)'
							END 
							IF @Period = 'month' BEGIN
								SET @SQL = @SQL + '
								AND (ISNULL(bd.BenefitAppliedDate,'''') < ''' + CAST(@DateStart as varchar(10)) + ''' OR bd.BenefitAppliedDate IS NULL)'
							END
							IF @Period = 'year' BEGIN
								SET @SQL = @SQL + '
								AND (ISNULL(bd.BenefitAppliedDate,'''') <= ''' + CAST(@DateEnd as varchar(10)) + ''' OR bd.BenefitAppliedDate IS NULL)'
							END
							SET @SQL = @SQL + '
							AND b.BenefitIntervalId NOT IN (	
								SELECT ISNULL(b.BenefitIntervalId,0)
									FROM [Benefit] b 
										JOIN [Task] t on b.TaskID = t.ID
										JOIN [BenefitDetail] bd ON b.ID = bd.BenefitID
									WHERE 1 = 1
										AND ISNULL(t.[Status],'''') <> ''misdirected''
										AND t.TaskType = ''remove_benefit'' '
							IF @Period = 'all' BEGIN
								SET @SQL = @SQL + '
										AND (ISNULL(bd.BenefitRemovedDate,'''') < ''' + CAST(@DateEnd as varchar(10)) + ''' OR bd.BenefitRemovedDate IS NULL) '
							END 
							IF @Period = 'month' BEGIN
								SET @SQL = @SQL + '
										AND (ISNULL(bd.BenefitRemovedDate,'''') < ''' + CAST(@DateStart as varchar(10)) + ''' OR bd.BenefitRemovedDate IS NULL) '
							END
							IF @Period = 'year' BEGIN
								SET @SQL = @SQL + '
										AND (ISNULL(bd.BenefitRemovedDate,'''') < ''' + CAST(@DateEnd as varchar(10)) + ''' OR bd.BenefitRemovedDate IS NULL) '
							END
							SET @SQL = @SQL + '
										GROUP BY b.BenefitIntervalId
									)
						GROUP BY b.BenefitIntervalId
						)
						AND (TaskType = ''add_benefit'' OR TaskType = ''extend_benefit'' OR TaskType = ''continue_benefit'')
						AND ISNULL(t.[Status],'''') <> ''misdirected''
						AND c.IsDeleted = 0 
						AND (ISNULL(c.CloseDate,'''') > ''' + CAST(@DateEnd as varchar(10)) + ''' or c.CloseDate IS NULL) '
						IF @Period = 'all' BEGIN
								SET @SQL = @SQL + '
						AND (ISNULL(bd.BenefitRemovedDate,'''') > ''' + CAST(@DateEnd as varchar(10)) + ''' OR bd.BenefitRemovedDate IS NULL) '
						END 
						IF @Period = 'year' BEGIN
								SET @SQL = @SQL + '
						AND (ISNULL(bd.BenefitRemovedDate,'''') > ''' + CAST(@DateEnd as varchar(10)) + ''' OR bd.BenefitRemovedDate IS NULL) '
						END
						IF @Period = 'month' BEGIN
								SET @SQL = @SQL + '
						AND (ISNULL(bd.BenefitRemovedDate,'''') > ''' + CAST(@DateEnd as varchar(10)) + ''' OR bd.BenefitRemovedDate IS NULL) '
						END
						SET @SQL = @SQL + '
												
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

EXEC [dbo].[spBenefitPopulation_2_Report] @Period='all',@Year='',@Month=''

*/
GO
/****** Object:  StoredProcedure [dbo].[spServicemember_Promo_Rate_End_Report]    Script Date: 12/26/2019 14:56:36 ******/
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

--;with CTE AS (
--	SELECT DISTINCT sm.PersonID,s.DateOfContact,s.MethodOfNotification,s.DateDMDCSearchPerformed,s.VerifyBySCRAOrMilOrders
--				,s.ActiveAccountEligible,s.BenefitApprovedDeniedPending,s.StatusCode
--				,s.NotEligReason,s.DenialReason,s.[90DayLetterSentOn]
--	FROM [SCRA_DB].[dbo].[Migration_History] s 
--	JOIN [dbo].[Servicemember] sm ON s.ServiceMemberID = sm.ServicememberID
--	) 
--	SELECT DISTINCT
--		--CAST(com.CommunicationDate	as DATE)	AS DateOfContact
--		COALESCE(cast(cte.DateOfContact as date), 
--					CASE WHEN cast(p.[Timestamp] as date) = '2019-02-15' THEN NULL ELSE cast(p.[timestamp] as date) END,
--					com.CommunicationDate)	
--				  							AS DateOfContact
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
--		--,CASE WHEN ct.SCRA_Code = 'auto' THEN 'Auto'
--		--	  WHEN ct.SCRA_Code = 'commercial' THEN 'Commercial Loan'
--		--	  WHEN ct.SCRA_Code = 'consumer_loan' THEN 'Consumer Loan'
--		--	  WHEN ct.SCRA_Code = 'credit_card' THEN 'Credit Card'
--		--	  WHEN ct.SCRA_Code = 'mortgage' THEN 'Mortgage'
--		--	  WHEN ct.SCRA_Code = 'safe_dep_box' THEN 'Safe Deposit Box'
--		--	  WHEN ISNULL(ct.SCRA_Code,'') = '' THEN ''
--		--	  ELSE 'Other' END
--		--									AS ProductType
--		,ct.Product_Type					AS ProductType
--		--,ct.SUB_PRODUCT_NAME				AS SubType
--		,CASE WHEN ISNULL(cnt.ProductName,'') = '' THEN ct.Product_SubType
--				ELSE cnt.ProductName END	AS SubType
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
--		,CASE WHEN cte.ActiveAccountEligible = 0 THEN 'No'
--			  WHEN cte.ActiveAccountEligible = 1 THEN 'Yes'
--			  ELSE NULL END					AS ActiveAccountEligible
--		,REPLACE(REPLACE(STUFF((SELECT ',' + note.Comment FROM dbo.Note note WHERE PersonID = p.ID ORDER BY note.[Timestamp] DESC FOR XML PATH('')),1,1,''),',',CHAR(13)+CHAR(10)+CHAR(13)+CHAR(10)),CHAR(34),CHAR(39)+CHAR(39)) 
--											AS Comments
--		,''									AS AdditionalComments
--		,bd.PromotionEndDate				AS [Promo Rate End Date]
--	FROM dbo.Person p 
--		outer apply(Select distinct FNumber from dbo.Customer where PersonID=p.ID and PersonID in (Select pp.ID As PersonId from Person pp 
--						where ( pp.ID = p.ID OR pp.ID IN (Select ServicememberId from dbo.Inquiry i WHERE i.ServicememberId = p.ID )))) cust
						
--		outer apply( Select distinct ID,CommunicationDate,LetterId,TaskId,PersonId,BenefitID from dbo.Communication where PersonID in (Select pp.ID As PersonId from Person pp 
--							where ( pp.ID = p.ID OR pp.ID IN (Select ServicememberId from dbo.Inquiry i WHERE i.ServicememberId = p.ID )))) com
							
--		outer apply (Select distinct  ContactMethodID from dbo.Inquiry where COALESCE(ServicememberId,PersonInquiringId) in (Select pp.ID As PersonId from Person pp 
--							where ( pp.ID = p.ID OR pp.ID IN (Select ServicememberId from dbo.Inquiry i WHERE i.ServicememberId = p.ID )))) r
--			LEFT JOIN dbo.ContactMethod cm 
--				ON r.ContactMethodId = cm.ID
				
--		outer apply (Select * from dbo.ActiveDuty a where a.PersonID in (Select pp.ID As PersonId from Person pp 
--							where ( pp.ID = p.ID OR pp.ID IN (Select ServicememberId from dbo.Inquiry i WHERE i.ServicememberId = p.ID )))) ad
--			INNER JOIN dbo.BranchOfService bos 
--				ON bos.ID = ad.BranchOfServiceID
				
--		outer apply (select * from dbo.Benefit bb where bb.PersonID in (Select pp.ID As PersonId from Person pp 
--							where ( pp.ID = p.ID OR pp.ID IN (Select ServicememberId from dbo.Inquiry i WHERE i.ServicememberId = p.ID ))
--									AND bb.ContractID IN (SELECT ID FROM dbo.[Contract] WHERE PersonID = p.ID and ID = bb.ContractID)
--									AND bb.ActiveDutyID IN (SELECT ID FROM ActiveDuty WHERE PersonID = p.ID AND ID = ad.ID) )) b
--			 LEFT JOIN dbo.BenefitDetail bd 
--				ON b.ID = bd.BenefitId
				
--		outer apply (select * from dbo.[Contract] c where b.ContractID = c.ID AND c.IsDeleted = 0 AND c.PersonID in (Select pp.ID As PersonId from Person pp 
--							where ( pp.ID = p.ID OR pp.ID IN (Select ServicememberId from dbo.Inquiry i WHERE i.ServicememberId = p.ID ))
--							AND c.ID = b.ContractID)) cnt
--			LEFT JOIN dbo.ContractType ct 
--				ON cnt.ContractTypeId = ct.ID	
				
--		outer apply(select distinct Comment from dbo.Note where PersonID in (Select pp.ID As PersonId from Person pp 
--							where ( pp.ID = p.ID OR pp.ID IN (Select ServicememberId from dbo.Inquiry i WHERE i.ServicememberId = p.ID )))) note
		
--		LEFT JOIN CTE cte ON p.ID = cte.PersonID

--		WHERE ISNULL(bd.PromotionEndDate,'') <> ''
		
--ORDER BY COALESCE(cast(cte.DateOfContact as date), 
--			CASE WHEN cast(p.[Timestamp] as date) = '2019-02-15' THEN NULL ELSE cast(p.[timestamp] as date) END,
--					com.CommunicationDate)	 DESC	

;WITH CTE as (
SELECT DISTINCT b.ID,b.BenefitIntervalId,ContractID,PersonID,ActiveDutyID,PromotionEndDate,TaskID from Benefit b LEFT JOIN BenefitDetail bd ON b.ID = bd.BenefitId where bd.PromotionEndDate IS NOT NULL AND ActiveDutyID <> 0)

SELECT DISTINCT 
	ISNULL(CONVERT(VARCHAR(10),COALESCE(mh.DateOfContact,i.InquiryDate),121),'')	as DateOfContact,
	p.ID																			as ServicememberID,
	p.FirstName																		as ServicememberFirstName,
	p.LastName																		as ServicememberLastName,
	p.MiddleInitial																	as ServicememberMiddleInitial,
	cust.FNumber																	as FNumber,
	p.SSN																			as SocialSecurityNumber,
	p.DOB																			as DateOfBirth,
	dbo.fnServiceBranchByID(ad.BranchOfServiceID)									as BranchOfService,
	ISNULL(CONVERT(VARCHAR(10),ad.StartDate,121),'')								as ADStartDate,
	ISNULL(CASE WHEN CONVERT(varchar(10),ad.EndDate,121) = '9999-12-31' 
		AND ISNULL(ad.StartDate,'') <> '' THEN '' ELSE 
			CASE WHEN ISNULL(ad.StartDate,'') <> '' THEN 
				CONVERT(VARCHAR(10),ad.EndDate,121) ELSE '' END END,'')				as ADEndDate,
	CASE ISNULL((SELECT TOP 1 CASE WHEN ISNULL(b1.[Status],'') <> '' 
					THEN UPPER(SUBSTRING(b1.[Status],1,1))+
						SUBSTRING(b1.[Status],2,LEN(b1.[Status]) - 1) ELSE '' END
						FROM [Benefit] b1 
						WHERE b1.BenefitIntervalId = b.BenefitIntervalId AND 
						ISNULL(b1.[Status],'') <> '' 
						ORDER BY b1.[Timestamp] DESC),'')
					WHEN 'Denied' THEN 'Denied' 
					WHEN  '' THEN ''
					ELSE 'Approved' END												as BenefitApprovedDeniedPending,
	ISNULL((SELECT TOP 1 CASE WHEN ISNULL(b1.[Status],'') <> '' 
			THEN UPPER(SUBSTRING(b1.[Status],1,1))+
				SUBSTRING(b1.[Status],2,LEN(b1.[Status]) - 1) ELSE '' END 
						FROM [Benefit] b1 
						WHERE b1.BenefitIntervalId = b.BenefitIntervalId 
						AND ISNULL(b1.[Status],'') <> '' 
						ORDER BY b1.[Timestamp] DESC),'')							as [Status],
	ISNULL(CONVERT(varchar(10),bd.BenefitAppliedDate,121),'')						as DateBenefitsApplied,
	--ISNULL(CONVERT(varchar(10),bd.BenefitEffectiveDate,121),'')						as BenefitEffectiveDate,
	--ISNULL(CONVERT(varchar(10),bd.ExpectedRemovalDate,121),'')						as ExpectedRemovalDate,
	ISNULL(CONVERT(varchar(10),bd.BenefitRemovedDate,121),'')						as DateBenefitsEnded,
	dbo.fnProductName(c.ContractTypeId)												as ProductType,
	dbo.fnProductSubName(cte.ContractID)											as SubType,
	ISNULL(COALESCE(CASE WHEN ISNULL(c.LegacyNo,'') = '' THEN NULL 
		ELSE dbo.LegacyNo_Format(c.LegacyNo) END,
			CASE WHEN ISNULL(c.CardNo,'') = '' THEN NULL 
				ELSE dbo.CardNo_Format(c.CardNo) END),'')							as AccountNum,
	ISNULL(CONVERT(varchar(10),c.OpenDate,121),'')									as StartDate,
	ISNULL(CONVERT(varchar(10),c.CloseDate,121),'')									as EndDate,
	'Yes'																			as ActiveAccountEligible,
	REPLACE(REPLACE(STUFF((SELECT ',' + note.Comment FROM dbo.Note note 
		WHERE PersonID = p.ID ORDER BY note.[Timestamp] DESC 
			FOR XML PATH('')),1,1,''),',',
			CHAR(13)+CHAR(10)+CHAR(13)+CHAR(10)),CHAR(34),CHAR(39)+CHAR(39))		as Comments,
	''																				as AdditionalComments,
	cte.PromotionEndDate															as [Promo Rate End Date]
	FROM CTE cte 
		JOIN Person p ON cte.PersonID = p.ID 
			LEFT JOIN ActiveDuty ad ON cte.ActiveDutyID = ad.ID
				LEFT JOIN Task t ON cte.TaskID = t.ID
					LEFT JOIN Inquiry i on t.InquiryID = i.ID
						LEFT JOIN Customer cust ON cte.PersonID = cust.PersonID
							LEFT JOIN Benefit b ON cte.ID = b.ID
								LEFT JOIN (SELECT bb.BenefitIntervalID
											,COALESCE(MIN(bd1.BenefitAppliedDate),MAX(bd1.BenefitAppliedDate)) as BenefitAppliedDate
											,COALESCE(MIN(bd1.BenefitEffectiveDate),MAX(bd1.BenefitEffectiveDate)) as BenefitEffectiveDate
											,COALESCE(MIN(bd1.BenefitRemovedDate),MAX(bd1.BenefitRemovedDate)) as BenefitRemovedDate
											,COALESCE(MIN(bd1.ExpectedRemovalDate),MAX(bd1.ExpectedRemovalDate)) as ExpectedRemovalDate 
											FROM [BenefitDetail] bd1 JOIN Benefit bb ON bd1.BenefitId = bb.ID GROUP BY bb.BenefitIntervalID) bd ON cte.BenefitIntervalId = bd.BenefitIntervalId
									LEFT JOIN [Contract] c ON cte.ContractID = c.ID
										LEFT JOIN (SELECT DateOfContact,p.ID FROM Migration_History mh JOIN Servicemember sm ON mh.ServiceMemberID = sm.ServicememberID JOIN Person p On sm.PersonID = p.ID) mh ON cte.PersonID = mh.ID
	ORDER BY cte.PromotionEndDate																							

/*
EXEC [dbo].[spServicemember_Promo_Rate_End_Report]
*/
GO
/****** Object:  StoredProcedure [dbo].[spInquiries_Report]    Script Date: 12/26/2019 14:56:36 ******/
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
	  
	  ,CASE WHEN i.PersonInquiringId <> p.ID THEN 'Yes' ELSE '' END as 'ServicememberIfDifferent'
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
/****** Object:  StoredProcedure [dbo].[spDMDC_Validation_Report]    Script Date: 12/26/2019 14:56:36 ******/
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
      
      ,ISNULL(CASE WHEN ad.PersonID IS NOT NULL AND i.IsOnActiveDuty = 1 THEN 'Yes' ELSE '' END,'') as [ServicememberOnActiveDuty]
      
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
/****** Object:  StoredProcedure [dbo].[spBenefitPopulation_Report]    Script Date: 12/26/2019 14:56:36 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Aleksey Mazur>
-- Create date: <10/28/2019>
-- Description:	<Benefit population Report>
-- =============================================
CREATE PROCEDURE [dbo].[spBenefitPopulation_Report] 
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
		
				SELECT DISTINCT b.BenefitIntervalId
					,cast(i.InquiryDate as DATE) as ContactDate
					,CASE ISNULL(i.IdentificationMethod,'') 
						WHEN 'internal' THEN 'Proactive'
						WHEN 'line_business' THEN 'Line of Business'
						WHEN 'customer' THEN 'Customer Originated'
						WHEN '' THEN ''
						ELSE ''
					END as IdentificationMethod
					
					,b.PersonID as SMID,sm.FNumber,smn.FirstName as SMFirstName,smn.MiddleInitial as SMMiddleInitial,smn.LastName as SMLastName
					,adr.Branch,adr.Reserv
					,CONVERT(VARCHAR(10),adr.ADSD,121) as ADSD
					,CASE WHEN CONVERT(varchar(10),adr.ADED,121) = '9999-12-31' AND ISNULL(adr.ADSD,'') <> '' THEN '' ELSE CASE WHEN ISNULL(adr.ADSD,'') <> '' THEN CONVERT(VARCHAR(10),adr.ADED,121) ELSE NULL END END as ADED 
					,adr.ADCount 
					
					,UPPER(SUBSTRING(b.[Status],1,1))+SUBSTRING(b.[Status],2,LEN(b.[Status]) - 1) as [Status],bd.BenefitAppliedDate,bd.BenefitEffectiveDate,bd.ExpectedRemovalDate,bd.BenefitRemovedDate 
					
					,c.PersonID as CustID,cust.FNumber as CustFNumber,p.FirstName as CustFirstName,p.MiddleInitial as CustMiddleInitial,p.LastName as CustLastName
					
					,dbo.PARTENON_Format(c.ContractNo) as ContractNo
					,CASE WHEN ISNULL(c.LegacyNo,'') = '' THEN dbo.CardNo_Format(c.CardNo) ELSE dbo.LegacyNo_Format(c.LegacyNo) END as AccountNo
					,dbo.fnProductName(c.ContractTypeId) as ProductType
					,dbo.fnProductSubName(c.ID) as ProductSubType
					,c.OpenDate as ProductOpenDate,c.CloseDate as ProductCloseDate
					
				FROM [Benefit] b 
						JOIN [BenefitDetail] bd ON b.ID = bd.BenefitID 
							JOIN [Contract] c ON (b.ContractID = c.ID)
								JOIN [Person] p ON c.PersonID = p.ID
									JOIN [Task] t on b.TaskID = t.ID
										JOIN Inquiry i on t.InquiryID = i.ID
											JOIN 
												(SELECT b.BenefitIntervalId ,MIN(ad.StartDate) as ADSD,MAX(ISNULL(ad.EndDate,'9999-12-31')) as ADED,ad.PersonID, COUNT(b.ActiveDutyID) as ADCount, 
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
							
							LEFT JOIN [BenefitDetail] bd ON b.ID = bd.BenefitID
							
						WHERE 1 = 1
							AND ISNULL(t.[Status],'') <> 'misdirected'
							AND t.TaskType = 'add_benefit'  
							AND b.BenefitIntervalId NOT IN (	
								SELECT b.BenefitIntervalId
									FROM [Benefit] b 
										JOIN [Task] t on b.TaskID = t.ID
										
										LEFT JOIN [BenefitDetail] bd ON b.ID = bd.BenefitID
										
									WHERE 1 = 1
										AND ISNULL(t.[Status],'') <> 'misdirected'
										AND t.TaskType = 'remove_benefit' GROUP BY b.BenefitIntervalId
									)
						GROUP BY b.BenefitIntervalId
						)
						AND TaskType = 'add_benefit' 
						AND ISNULL(t.[Status],'') <> 'misdirected'
						AND c.IsDeleted = 0
						AND b.PersonID NOT IN (2113,2138,2139)
					ORDER BY b.PersonID
				
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

EXEC [dbo].[spBenefitPopulation_Report]

*/
GO
/****** Object:  StoredProcedure [dbo].[spAffiliate_Report]    Script Date: 12/26/2019 14:56:36 ******/
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
/****** Object:  StoredProcedure [dbo].[sp30DaysList_Report]    Script Date: 12/26/2019 14:56:36 ******/
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
		 --,bd.ExpectedRemovalDate,bd.BenefitRemovedDate
		 ,COALESCE(bd.ExpectedRemovalDate,bd.BenefitRemovedDate) as BenefitRemovedDate
		 ,DateDiff(DAY,CAST(GETDATE() as DATE),COALESCE(bd.ExpectedRemovalDate,bd.BenefitRemovedDate)) AS DaysLeft
		 ,dbo.fnProductName(c.ContractTypeId) + CASE WHEN LEN(dbo.fnProductSubName(c.ID)) = 0 THEN '' ELSE ' - ' + dbo.fnProductSubName(c.ID) END as SUB_PRODUCT_NAME
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
