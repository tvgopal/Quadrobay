create or replace PACKAGE XXAV_PO_PRINT_UTIL_PKG
AS
      
      PROCEDURE insert_articles(p_po_header_id number);
      
      function get_contract_number (p_requisition_line_id number) return varchar2;

      PROCEDURE delete_articles(p_request_id number);
      
END XXAV_PO_PRINT_UTIL_PKG;