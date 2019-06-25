USE [SCRA_DB]
GO
/****** Object:  StoredProcedure [dbo].[spPerson_List_noFilter]    Script Date: 06/25/2019 12:52:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPerson_List_noFilter]
	@Search VARCHAR(MAX),
	@Ssn VARCHAR(9) = NULL,
	@phone VARCHAR(10) = NULL,
	@email VARCHAR(128) = NULL

AS
BEGIN
	SET NOCOUNT ON;
	declare @sql VARCHAR(MAX)
	
	 
	IF @Search IS NULL BEGIN
		SET @Search = ISNULL(@Search,'')
	END ELSE BEGIN
		SET @Search = @Search
	END

	IF @Ssn IS NULL BEGIN
		SET @Ssn = ISNULL(@Ssn,'')
	END ELSE BEGIN
		IF @Ssn = '000000000' BEGIN
			SET @Ssn = ''
		END ELSE BEGIN	
			SET @Ssn = @Ssn
		END
	END

	IF @phone IS NULL BEGIN
		SET @phone = ISNULL(@phone,'')
	END ELSE BEGIN
		IF @phone = '0000000000' BEGIN
			SET @phone = ''
		END ELSE BEGIN	
			SET @phone = @phone
		END
	END

	IF @email IS NULL BEGIN
		SET @email = ISNULL(@email,'')
	END ELSE BEGIN		
		SET @email = @email		
	END


	SET @sql = '
	SELECT t1.[ID]
      ,t1.[FirstName]
      ,t1.[LastName]
      ,t1.[MiddleInitial]
      ,t1.[SSN]
      ,t1.[DOB] 
	  ,t1.[Address1]
      ,t1.[Address2]
      ,t1.[City]
      ,t1.[State]
      ,t1.[Zip]    
      ,t1.[Phone]
      ,t1.[Email]
	  ,cm.[Name] as ContactMethod
      ,t1.[Timestamp]
      ,t1.[ModifiedBy]
	  ,t2.[FNumber]
      ,t1.[Origin]
	FROM [dbo].[Person] t1 
	LEFT JOIN [dbo].[Customer] t2 ON t1.[ID] = t2.[PersonID]
	LEFT JOIN ContactMethod cm ON cm.Id = t1.[ContactMethodID]
	WHERE 1=1 AND ISNULL([Search],'''') LIKE ''%'+RTRIM(LTRIM(@Search))+'%'''
  
	IF LEN(@Ssn) != 0 BEGIN
		SET @sql = @sql + 'OR SSN = ''' + @Ssn + ''''
	END

	IF LEN(@phone) != 0 BEGIN
		SET @sql = @sql + 'OR Phone = ''' + @phone + ''''
	END

	IF LEN(@email) != 0 BEGIN
		SET @sql = @sql + 'OR Email = ''' + @email + ''''
	END
   
   SET @sql = @sql + '
   ORDER BY [LastName], [FirstName]'


   PRINT @sql
   EXEC(@sql)
    
END

/*

EXEC [spPerson_List_noFilter] @Search = 'Taylor Swift', @Ssn = '111223333'
EXEC [spPerson_List_noFilter] @Search = 'Taylor Swift', @Ssn = '000000000', @phone = '7187585070', @email='ccody@wdsystems.com'
EXEC [spPerson_List_noFilter] @Search = 'Taylor Swift', @Ssn = '', @phone = '0000000000', @email='ccody@wdsystems.com'

*/
GO
