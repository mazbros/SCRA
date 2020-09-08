using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Runtime.InteropServices;
using Microsoft.Office.Interop.Excel;
using Scra.Views.Reports;
using DataTable = System.Data.DataTable;

namespace Scra.Tools
{
    public class ExportToExcel
    {
        private readonly ReportsListViewModel _reportsListViewModel;

        public ExportToExcel(ReportsListViewModel reportsListViewModel)
        {
            _reportsListViewModel = reportsListViewModel;
        }

        public void Export(DataTable data, string REPORT_NAME)
        {
            var StrDateRange =
                (_reportsListViewModel.RunDate != null &&
                 _reportsListViewModel.RunDate2 != null && _reportsListViewModel.RunDate == _reportsListViewModel.RunDate2)
                    ? "As_Of_" + string.Format("{0:MMddyyyy}", _reportsListViewModel.RunDate2)
                    : (_reportsListViewModel.RunDate != null ? string.Format("{0:MMddyyyy}", _reportsListViewModel.RunDate) + "-" : "") +
                      (_reportsListViewModel.RunDate2 != null ? string.Format("{0:MMddyyyy}", _reportsListViewModel.RunDate2) : "");
            var StrDate = string.Format("{0:MMddyyyy}", DateTime.Today);
            var FileName = (StrDateRange.Length > 0 ? StrDateRange + "_" : "") + REPORT_NAME +
                           "_" + (_reportsListViewModel.ProductCategory.Length > 0 ? _reportsListViewModel.ProductCategory.Replace(" ", "_") + "_" : "") + StrDate;
            var TempFolder = DirectoryUtility.GetTempDirectory();
            var FilePath = Path.Combine(TempFolder, FileName + ".xlsx");

            try
            {
                var excel = new Application();
                var wb = excel.Workbooks.Add();
                var ws = (Worksheet)wb.ActiveSheet;

                for (var Idx = 0; Idx < data.Columns.Count; Idx++)
                {
                    ws.Range["A1"].Offset[0, Idx].Value = data.Columns[Idx].ColumnName;
                }

                for (var Idx = 0; Idx < data.Rows.Count; Idx++)
                {
                    ws.Range["A2"].Offset[Idx].Resize[1, data.Columns.Count].Value = data.Rows[Idx].ItemArray;
                }

                var Header = ws.Range["A1"].Offset[0].Resize[1, data.Columns.Count].Columns;
                Header.Cells.Interior.Color = Color.Red;
                Header.Cells.Font.Color = Color.White;
                Header.Cells.Font.Bold = true;

                var SourceRange = ws.UsedRange;
                FormatAsTable(SourceRange, "Table1", "TableStyleMedium17");
                SourceRange.Columns.AutoFit();

                var emptyRow = 0;
                var needAdjustment = 0;
                for (var col = 1; col <= data.Columns.Count - 1; col++)
                {
                    var test = ws.Range["A2"].Offset[0].Resize[1, data.Columns.Count].Cells[1, col].Value;

                    if (test != null)
                    {
                        emptyRow++;
                        needAdjustment = col;
                    }
                }

                if (emptyRow == 1)
                {
                    var messageRange = ws.Range["A2"].Offset[0].Resize[1, data.Columns.Count].Columns;
                    messageRange.Cells.Interior.Color = Color.Yellow;
                    messageRange.Cells.Font.Color = Color.Red;
                    messageRange.Cells.Font.Bold = true;
                }

                ws.Columns[needAdjustment].ColumnWidth = 14;

                // SOLUTION FOR LONG VERTICAL COMMENTS EXPANDING THE HEIGHT OF THE ROW
                for (var Idx = 0; Idx < data.Rows.Count; Idx++)
                {
                    ws.Range["A2"].Offset[Idx].Resize[1, data.Columns.Count].VerticalAlignment = XlVAlign.xlVAlignTop;

                    if (ws.Range["A2"].Offset[Idx].Resize[1, data.Columns.Count].Height > 15)
                    {
                        ws.Range["A2"].Offset[Idx].Resize[1, data.Columns.Count].EntireRow.RowHeight = 15;
                    }
                }

                ws.Name = FileName.Length > 31 ? FileName.Substring(0, 31) : FileName;

                excel.DisplayAlerts = false;

                ws.Range["A1"].Select();

                ws.Application.ActiveWindow.WindowState = XlWindowState.xlNormal;
                ws.Application.ActiveWindow.FreezePanes = false;
                ws.Application.ActiveWindow.SplitRow = 1;
                ws.Application.ActiveWindow.FreezePanes = true;

                try
                {
                    wb.SaveAs(FilePath, XlFileFormat.xlWorkbookDefault, Type.Missing, Type.Missing,
                        false,
                        false,
                        XlSaveAsAccessMode.xlNoChange, XlSaveConflictResolution.xlLocalSessionChanges, Type.Missing, Type.Missing);
                }
                catch (COMException ex)
                {
                    if (ex.Message.StartsWith("Cannot access '" + FileName + ".xlsx'.")) _reportsListViewModel._messageDialog.Warning("The file with the same name is already open.\n Please close it and try again.");
                    _reportsListViewModel._shellViewModel.IsUiBusy = false;
                    return;
                }

                //Cleanup
                GC.Collect();
                GC.WaitForPendingFinalizers();
                wb.Close(true, FilePath, Type.Missing);
                excel.Quit();
                Marshal.FinalReleaseComObject(SourceRange);
                Marshal.FinalReleaseComObject(Header);
                Marshal.FinalReleaseComObject(ws);
                Marshal.FinalReleaseComObject(wb);
                Marshal.FinalReleaseComObject(excel);

                if (FileHelper.IsFileLocked(FilePath))
                {
                    var message = String.Format("File {0} is locked. Please, close the file and repeat export.", FileName + ".xlsx");
                    _reportsListViewModel._messageDialog.Warning(message);
                }
                else
                {
                    //FileHelper.Open(FilePath);
					var xlApp = new Application();
					Microsoft.Office.Interop.Excel._Workbook workBook;
					xlApp.WindowState = XlWindowState.xlNormal;
					xlApp.Visible = true;
					workBook = xlApp.Workbooks.Open(FilePath,0,false,5,"","",true,XlPlatform.xlWindows,"\t",false,false,0,true,1,0);
					workBook.Activate();
                }
            }
            catch (COMException ex)
            {
                _reportsListViewModel._messageDialog.Warning("Error accessing Excel: " + ex.Message);
            }
            catch (Exception ex)
            {
                _reportsListViewModel._messageDialog.Warning("Error: " + ex.Message);
            }

            //Kill EXCEL COM processes
            var PROC = Process.GetProcessesByName("EXCEL");
            foreach (var PK in PROC)
            {
                //User process always have window name, COM process do not
                if (PK.MainWindowTitle.Length == 0)
                {
                    PK.Kill();
                }
            }
        }

        public void ExportMultiTab(List<DataTable> dataSets, List<string> REPORT_NAMES)
        {
            var StrDateRange =
                (_reportsListViewModel.RunDate != null &&
                 _reportsListViewModel.RunDate2 != null && _reportsListViewModel.RunDate == _reportsListViewModel.RunDate2)
                    ? "As_Of_" + string.Format("{0:MMddyyyy}", _reportsListViewModel.RunDate2)
                    : (_reportsListViewModel.RunDate != null ? string.Format("{0:MMddyyyy}", _reportsListViewModel.RunDate) + "-" : "") +
                      (_reportsListViewModel.RunDate2 != null ? string.Format("{0:MMddyyyy}", _reportsListViewModel.RunDate2) : "");
            var StrDate = string.Format("{0:MMddyyyy}", DateTime.Today);
            var FileName = (StrDateRange.Length > 0 ? StrDateRange + "_" : "") + "SLA_Reports" +
                           "_" + (_reportsListViewModel.ProductCategory.Length > 0 ? _reportsListViewModel.ProductCategory.Replace(" ", "_") + "_" : "") + StrDate;
            var TempFolder = DirectoryUtility.GetTempDirectory();
            var FilePath = Path.Combine(TempFolder, FileName + ".xlsx");

            try
            {
                var excel = new Application();
                var wb = excel.Workbooks.Add();
                var ws = (Worksheet)wb.ActiveSheet;

                for (var i = 0; i < dataSets.Count; i++)
                {
                    for (var Idx = 0; Idx < dataSets[i].Columns.Count; Idx++)
                    {
                        ws.Range["A1"].Offset[0, Idx].Value = dataSets[i].Columns[Idx].ColumnName;
                    }

                    for (var Idx = 0; Idx < dataSets[i].Rows.Count; Idx++)
                    {
                        ws.Range["A2"].Offset[Idx].Resize[1, dataSets[i].Columns.Count].Value = dataSets[i].Rows[Idx].ItemArray;
                    }

                    var Header = ws.Range["A1"].Offset[0].Resize[1, dataSets[i].Columns.Count].Columns;
                    Header.Cells.Interior.Color = Color.Red;
                    Header.Cells.Font.Color = Color.White;
                    Header.Cells.Font.Bold = true;

                    var SourceRange = ws.UsedRange;
                    FormatAsTable(SourceRange, "Table1", "TableStyleMedium17");
                    SourceRange.Columns.AutoFit();

                    var emptyRow = 0;
                    var needAdjustment = 0;
                    for (var col = 1; col <= dataSets[i].Columns.Count - 1; col++)
                    {
                        var test = ws.Range["A2"].Offset[0].Resize[1, dataSets[i].Columns.Count].Cells[1, col].Value;

                        if (test != null)
                        {
                            emptyRow++;
                            needAdjustment = col;
                        }
                    }

                    if (emptyRow == 1)
                    {
                        var messageRange = ws.Range["A2"].Offset[0].Resize[1, dataSets[i].Columns.Count].Columns;
                        messageRange.Cells.Interior.Color = Color.Yellow;
                        messageRange.Cells.Font.Color = Color.Red;
                        messageRange.Cells.Font.Bold = true;
                    }

                    ws.Columns[needAdjustment].ColumnWidth = 14;

                    // SOLUTION FOR LONG VERTICAL COMMENTS EXPANDING THE HEIGHT OF THE ROW
                    for (var Idx = 0; Idx < dataSets[i].Rows.Count; Idx++)
                    {
                        ws.Range["A2"].Offset[Idx].Resize[1, dataSets[i].Columns.Count].VerticalAlignment = XlVAlign.xlVAlignTop;

                        if (ws.Range["A2"].Offset[Idx].Resize[1, dataSets[i].Columns.Count].Height > 15)
                        {
                            ws.Range["A2"].Offset[Idx].Resize[1, dataSets[i].Columns.Count].EntireRow.RowHeight = 15;
                        }
                    }

                    ws.Name = (REPORT_NAMES[i].Length > 31 ? REPORT_NAMES[i].Substring(0, 31) : REPORT_NAMES[i]).Replace("_", " ");

                    excel.DisplayAlerts = false;

                    ws.Range["A1"].Select();

                    ws.Application.ActiveWindow.WindowState = XlWindowState.xlNormal;
                    ws.Application.ActiveWindow.FreezePanes = false;
                    ws.Application.ActiveWindow.SplitRow = 1;
                    ws.Application.ActiveWindow.FreezePanes = true;


                    ws = (Worksheet)wb.Worksheets.Add(After: wb.Sheets[wb.Worksheets.Count]);
                    //((Microsoft.Office.Interop.Excel._Worksheet)ws).Activate();
                }

                wb.ActiveSheet.Delete();
                wb.Sheets[1].Activate();

                try
                {
                    wb.SaveAs(FilePath, XlFileFormat.xlWorkbookDefault, Type.Missing, Type.Missing,
                        false,
                        false,
                        XlSaveAsAccessMode.xlNoChange, XlSaveConflictResolution.xlLocalSessionChanges, Type.Missing, Type.Missing);
                }
                catch (COMException ex)
                {
                    if (ex.Message.StartsWith("Cannot access '" + FileName + ".xlsx'.")) _reportsListViewModel._messageDialog.Warning("The file with the same name is already open.\n Please close it and try again.");
                    _reportsListViewModel._shellViewModel.IsUiBusy = false;
                    return;
                }

                //Cleanup
                GC.Collect();
                GC.WaitForPendingFinalizers();
                wb.Close(true, FilePath, Type.Missing);
                excel.Quit();
                Marshal.FinalReleaseComObject(wb);
                Marshal.FinalReleaseComObject(excel);

                if (FileHelper.IsFileLocked(FilePath))
                {
                    var message = String.Format("File {0} is locked. Please, close the file and repeat export.", FileName + ".xlsx");
                    _reportsListViewModel._messageDialog.Warning(message);
                }
                else
                {
                    //FileHelper.Open(FilePath);
					var xlApp = new Application();
					Microsoft.Office.Interop.Excel._Workbook workBook;
					xlApp.WindowState = XlWindowState.xlNormal;
					xlApp.Visible = true;
					workBook = xlApp.Workbooks.Open(FilePath,0,false,5,"","",true,XlPlatform.xlWindows,"\t",false,false,0,true,1,0);
					workBook.Activate();
                }
            }
            catch (COMException ex)
            {
                _reportsListViewModel._messageDialog.Warning("Error accessing Excel: " + ex.Message);
            }
            catch (Exception ex)
            {
                _reportsListViewModel._messageDialog.Warning("Error: " + ex.Message);
            }

            //Kill EXCEL COM processes
            var PROC = Process.GetProcessesByName("EXCEL");
            foreach (var PK in PROC)
            {
                //User process always have window name, COM process do not
                if (PK.MainWindowTitle.Length == 0)
                {
                    PK.Kill();
                }
            }
        }

        private static void FormatAsTable(Range SourceRange, string TableName, string TableStyleName)
        {
            SourceRange.Worksheet.ListObjects.Add(XlListObjectSourceType.xlSrcRange,
                    SourceRange, Type.Missing, XlYesNoGuess.xlYes, Type.Missing).Name =
                TableName;
            SourceRange.Select();
            SourceRange.Worksheet.ListObjects[TableName].TableStyle = TableStyleName;
        }
    }
}