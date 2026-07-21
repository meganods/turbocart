import 'dart:convert';
import 'dart:js' as js;

class CsvExporter {
  static String convertListToCsv(List<List<dynamic>> rows) {
    return rows.map((row) {
      return row.map((cell) {
        final str = cell.toString().replaceAll('"', '""');
        if (str.contains(',') || str.contains('\n') || str.contains('"')) {
          return '"$str"';
        }
        return str;
      }).join(',');
    }).join('\n');
  }

  static void exportToCsv({
    required List<List<dynamic>> rows,
    required String filename,
  }) {
    try {
      final csvString = convertListToCsv(rows);
      final bytes = utf8.encode(csvString);
      final base64String = base64Encode(bytes);
      
      js.context.callMethod('eval', ['''
        (function() {
          var link = document.createElement("a");
          link.href = "data:text/csv;charset=utf-8;base64,$base64String";
          link.download = "$filename";
          document.body.appendChild(link);
          link.click();
          document.body.removeChild(link);
        })()
      ''']);
    } catch (e) {
      // Fallback
    }
  }
}
