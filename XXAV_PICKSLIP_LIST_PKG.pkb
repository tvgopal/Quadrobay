CREATE OR REPLACE PACKAGE BODY XXAV_PICKSLIP_LIST_PKG
IS
   FUNCTION UPDATE_MOVE_ORDER (P_MOVE_ORDER_LOW    IN NUMBER DEFAULT NULL,
                               P_MOVE_ORDER_HIGH   IN NUMBER DEFAULT NULL)
      RETURN BOOLEAN
   AS
   BEGIN
      FOR mv_rec
         IN (SELECT request_number
               FROM mtl_txn_request_headers
              WHERE request_number BETWEEN P_MOVE_ORDER_LOW
                                       AND P_MOVE_ORDER_HIGH)
      LOOP
         EXIT WHEN mv_rec.request_number IS NULL;

         UPDATE mtl_txn_request_headers
            SET attribute7 = SYSDATE
          WHERE request_number = mv_rec.request_number;
      END LOOP;

      COMMIT;
      RETURN TRUE;
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG, 'Error : ' || SQLERRM);
         RETURN FALSE;
   END;
END XXAV_PICKSLIP_LIST_PKG;