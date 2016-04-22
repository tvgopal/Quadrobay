/* Formatted on 2015/08/18 15:44 (Formatter Plus v4.8.8) */
CREATE OR REPLACE PACKAGE xxav_move_order_pkg AUTHID CURRENT_USER
IS
   /*
   REM +==========================================================================+
   REM
   REM NAME
   REM XXDTS_MOVE_ORDER_PKG.pks
   REM
   REM PROGRAM TYPE  -> PL/SQL Package Spec
   REM
   REM PURPOSE
   REM  The purpose of this package is to create the Move Order
   REM
   REM
   REM  This package is primarily used by <<Customer>> for Shipping Customization
   REM
   REM HISTORY
   REM ===========================================================================
   REM  Date          Author                  Activity
   REM ===========================================================================
   REM 06-Aug-15     SKUMAR    Created
   REM ===========================================================================
   REM Status Used
   REM ===========
   REM      'U' or NULL - Unvalidated
   REM      'V'         - Validated
   REM      'S1'        - Move Order Created
   REM      'S2'        - Move Order Allocated
   REM      'S'         - Move Order Transacted
   REM      'E'         - Errored due to various reasons
   REM ===========================================================================*/
   g_conc_req_id   NUMBER;

   PROCEDURE print_log (p_debug_flag IN VARCHAR2, msg IN VARCHAR2);

   PROCEDURE print_out (msg IN VARCHAR2);

   PROCEDURE load_staging (p_debug_flag IN VARCHAR2);

   PROCEDURE validate_move_order (
      p_debug_flag           IN   VARCHAR2,
      p_contract_number      IN   VARCHAR2,
      p_delivery_id          IN   NUMBER,
      p_delivery_detail_id   IN   NUMBER
   );

   PROCEDURE submit_process (
      errbuf               OUT      VARCHAR2,
      retcode              OUT      VARCHAR2,
      p_debug_flag           IN       VARCHAR2 DEFAULT 'Y',
      p_contract_number      IN       VARCHAR2 DEFAULT NULL,
      p_delivery_id          IN       NUMBER DEFAULT NULL,
      p_delivery_detail_id   IN       NUMBER DEFAULT NULL,
      p_run_flag             IN       VARCHAR2 DEFAULT 'L'
   );

   PROCEDURE execute_move_order (
      p_debug_flag           IN       VARCHAR2,
      p_contract_number      IN       VARCHAR2,
      p_delivery_id          IN       NUMBER,
      p_delivery_detail_id   IN       NUMBER,
      x_hdr_rec              OUT      inv_move_order_pub.trohdr_rec_type,
      x_line_tbl             OUT      inv_move_order_pub.trolin_tbl_type,
      x_return_status        OUT      VARCHAR2,
      x_msg_data             OUT      VARCHAR2,
      x_msg_count            OUT      NUMBER
   );

   PROCEDURE allocate_move_order (
      p_debug_flag      IN       VARCHAR2,
      p_line_tbl        IN       inv_move_order_pub.trolin_tbl_type,
      x_return_status   OUT      VARCHAR2,
      x_msg_data        OUT      VARCHAR2,
      x_msg_count       OUT      NUMBER
   );

   PROCEDURE transact_move_order (
      p_debug_flag      IN       VARCHAR2,
      p_move_order_id   IN       NUMBER,
      x_return_status   OUT      VARCHAR2
   );

   PROCEDURE get_con_id (p_request_id NUMBER);

   PROCEDURE get_log_out (p_lo_req_id NUMBER);

   PROCEDURE read_log_out (p_log_fname VARCHAR2, p_out_fname VARCHAR2);

   PROCEDURE send_logout_mail (
      p_attach_log   IN   CLOB DEFAULT NULL,
      p_attach_out   IN   CLOB DEFAULT NULL
   );
END xxav_move_order_pkg;