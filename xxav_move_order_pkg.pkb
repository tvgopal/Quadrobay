/* Formatted on 2015/08/19 18:43 (Formatter Plus v4.8.8) */
CREATE OR REPLACE PACKAGE BODY xxav_move_order_pkg
AS
   /*
   REM +==========================================================================+
   REM
   REM NAME
   REM XXDTS_MOVE_ORDER_PKG.pkb
   REM
   REM PROGRAM TYPE  -> PL/SQL Package Body
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
   l_header_rec      inv_move_order_pub.trohdr_rec_type;
   l_line_tbl        inv_move_order_pub.trolin_tbl_type;
   x_return_status   VARCHAR2 (1);
   x_msg_data        VARCHAR2 (4000);
   x_msg_count       NUMBER;
   p_request_id      NUMBER;
   g_request_id      NUMBER;

   PROCEDURE print_log (p_debug_flag IN VARCHAR2, msg IN VARCHAR2)
   IS
   BEGIN
      IF (p_debug_flag = 'Y')
      THEN
         fnd_file.put_line (fnd_file.LOG,
                               TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                            || ': '
                            || msg
                           );
      END IF;
   END print_log;

   PROCEDURE print_out (msg IN VARCHAR2)
   IS
   BEGIN
      fnd_file.put_line (fnd_file.output, msg);
   END print_out;

   PROCEDURE submit_process (
      errbuf                 OUT      VARCHAR2,
      retcode                OUT      VARCHAR2,
      p_debug_flag           IN       VARCHAR2 DEFAULT 'Y',
      p_contract_number      IN       VARCHAR2 DEFAULT NULL,
      p_delivery_id          IN       NUMBER DEFAULT NULL,
      p_delivery_detail_id   IN       NUMBER DEFAULT NULL,
      p_run_flag             IN       VARCHAR2 DEFAULT 'L'
   )
   IS
      l_hdr_rec    inv_move_order_pub.trohdr_rec_type
                                      := inv_move_order_pub.g_miss_trohdr_rec;
      l_line_tbl   inv_move_order_pub.trolin_tbl_type
                                      := inv_move_order_pub.g_miss_trolin_tbl;
   BEGIN
      retcode := 0;

      IF p_run_flag = 'A'
      THEN
         print_log (p_debug_flag, 'Running in ALL Mode ');
         load_staging (p_debug_flag);
         validate_move_order (p_debug_flag,
                              p_contract_number,
                              p_delivery_id,
                              p_delivery_detail_id
                             );
         execute_move_order (p_debug_flag,
                             p_contract_number,
                             p_delivery_id,
                             p_delivery_detail_id,
                             l_header_rec,
                             l_line_tbl,
                             x_return_status,
                             x_msg_data,
                             x_msg_count
                            );
      ELSIF p_run_flag = 'L'
      THEN
         print_log (p_debug_flag, 'Running in LOAD Mode ');
         load_staging (p_debug_flag);
      ELSIF p_run_flag = 'V'
      THEN
         print_log (p_debug_flag, 'Running in VALIDATE Mode ');
         validate_move_order (p_debug_flag,
                              p_contract_number,
                              p_delivery_id,
                              p_delivery_detail_id
                             );
      ELSIF p_run_flag = 'E'
      THEN
         print_log (p_debug_flag, 'Running in EXECUTE Mode ');
         execute_move_order (p_debug_flag,
                             p_contract_number,
                             p_delivery_id,
                             p_delivery_detail_id,
                             l_header_rec,
                             l_line_tbl,
                             x_return_status,
                             x_msg_data,
                             x_msg_count
                            );
      ELSIF p_run_flag = 'LV'
      THEN
         print_log (p_debug_flag, 'Running in LOAD and VALIDATE Mode ');
         load_staging (p_debug_flag);
         validate_move_order (p_debug_flag,
                              p_contract_number,
                              p_delivery_id,
                              p_delivery_detail_id
                             );
      ELSIF p_run_flag = 'VE'
      THEN
         print_log (p_debug_flag, 'Running in VALIDATE and EXECUTE Mode ');
         validate_move_order (p_debug_flag,
                              p_contract_number,
                              p_delivery_id,
                              p_delivery_detail_id
                             );
         execute_move_order (p_debug_flag,
                             p_contract_number,
                             p_delivery_id,
                             p_delivery_detail_id,
                             l_header_rec,
                             l_line_tbl,
                             x_return_status,
                             x_msg_data,
                             x_msg_count
                            );
      END IF;
   END;

   PROCEDURE load_staging (p_debug_flag IN VARCHAR2)
   IS
      CURSOR c1
      IS
         SELECT b.ship_from_org_id organization_id,
                a.k_number_disp description, w1.source_header_number,
                w.delivery_id, w.delivery_detail_id,
                'Requisition' move_order_type,
                'Move Order Transfer' transaction_type,
                'NCSTK' from_subinventory_code,
                'STAGING' to_subinventory_code, SYSDATE date_required,
                inv.segment1 item, inv.inventory_item_id, u.uom_code,
                u.quantity, p.segment1 project_number, t.task_number,
                
                -- 'NCSTK||'||b.project_id||'|'||b.task_id source_locator,
                'NSCTK.1.1.5249.137179' source_locator,
                p.segment1 source_locator_project,
                t.task_number source_locator_task,
                'STAGING.1.1..' destination_locator_locator,
                
                -- 'STAGING|1||' destination_locator_locator,
                p.segment1 destination_locator_project,
                t.task_number destination_locator_task,
                (SELECT    (SELECT a.k_number_disp
                              FROM oke.oke_k_headers a,
                                   oke.oke_k_deliverables_b b
                             WHERE a.k_header_id = b.k_header_id
                               AND b.deliverable_id = w.source_line_id)
                        || ': '
                        || (SELECT kl.line_number
                              FROM oke.oke_k_deliverables_b b,
                                   okc.okc_k_lines_b kl
                             WHERE b.k_line_id = kl.ID
                               AND b.deliverable_id = w.source_line_id)
                        || ': '
                        || (SELECT b.deliverable_num
                              FROM oke.oke_k_deliverables_b b
                             WHERE b.deliverable_id = w.source_line_id)
                   FROM DUAL) move_order_reference,
                NULL request_number, NULL attribute1, NULL attribute2,
                NULL attribute3, NULL attribute4, NULL attribute5,
                NULL attribute6, NULL attribute7, NULL attribute8,
                NULL attribute9, NULL attribute10, NULL attribute11,
                NULL attribute12, NULL attribute13, NULL attribute14,
                NULL attribute15, SYSDATE creation_date, -1 created_by,
                SYSDATE last_update_date, -1 last_updated_by,
                NULL last_update_login, 'U' error_status, NULL error_message
           FROM wsh_deliverables_v w1,
                wsh_deliverables_v w,
                hr.hr_all_organization_units o,
                oke.oke_k_deliverables_b b,
                oke.oke_k_headers a,
                inv.mtl_system_items_b inv,
                apps.oke_k_deliverables_vl u,
                pa.pa_projects_all p,
                pa.pa_tasks t
          WHERE w.source_code = 'OKE'
            AND w.released_status = 'X'
            AND w.source_line_id = b.deliverable_id
            AND b.ship_from_org_id = o.organization_id
            AND a.k_header_id = b.k_header_id
            AND b.item_id = inv.inventory_item_id
            AND b.ship_from_org_id = inv.organization_id
            AND b.deliverable_id = u.deliverable_id
            AND w.delivery_detail_id = w1.delivery_detail_id
            AND b.project_id = p.project_id(+)
            AND b.task_id = t.task_id(+)
            AND NOT EXISTS (
                           SELECT 1
                             FROM xxav_move_order_stg wdd
                            WHERE wdd.delivery_detail_id =
                                                          w.delivery_detail_id);

      l_counter   NUMBER := 0;
   BEGIN
      FOR c1_rec IN c1
      LOOP
         l_counter := l_counter + 1;

         INSERT INTO xxav_move_order_stg
                     (organization_id, description,
                      contract_number, delivery_id,
                      delivery_detail_id, move_order_type,
                      transaction_type,
                      from_subinventory_code,
                      to_subinventory_code, date_required,
                      item, inventory_item_id,
                      uom_code, quantity,
                      project_number, task_number,
                      source_locator, source_locator_project,
                      source_locator_task,
                      destination_locator,
                      destination_locator_project,
                      destination_locator_task,
                      move_order_reference, request_number,
                      attribute1, attribute2,
                      attribute3, attribute4,
                      attribute5, attribute6,
                      attribute7, attribute8,
                      attribute9, attribute10,
                      attribute11, attribute12,
                      attribute13, attribute14,
                      attribute15, creation_date,
                      created_by, last_update_date,
                      last_updated_by, last_update_login,
                      error_status, error_message
                     )
              VALUES (c1_rec.organization_id, c1_rec.description,
                      c1_rec.source_header_number, c1_rec.delivery_id,
                      c1_rec.delivery_detail_id, c1_rec.move_order_type,
                      c1_rec.transaction_type,
                      c1_rec.from_subinventory_code,
                      c1_rec.to_subinventory_code, c1_rec.date_required,
                      c1_rec.item, c1_rec.inventory_item_id,
                      c1_rec.uom_code, c1_rec.quantity,
                      c1_rec.project_number, c1_rec.task_number,
                      c1_rec.source_locator, c1_rec.source_locator_project,
                      c1_rec.source_locator_task,
                      c1_rec.destination_locator_locator,
                      c1_rec.destination_locator_project,
                      c1_rec.destination_locator_task,
                      c1_rec.move_order_reference, c1_rec.request_number,
                      c1_rec.attribute1, c1_rec.attribute2,
                      c1_rec.attribute3, c1_rec.attribute4,
                      c1_rec.attribute5, c1_rec.attribute6,
                      c1_rec.attribute7, c1_rec.attribute8,
                      c1_rec.attribute9, c1_rec.attribute10,
                      c1_rec.attribute11, c1_rec.attribute12,
                      c1_rec.attribute13, c1_rec.attribute14,
                      c1_rec.attribute15, c1_rec.creation_date,
                      c1_rec.created_by, c1_rec.last_update_date,
                      c1_rec.last_updated_by, c1_rec.last_update_login,
                      c1_rec.error_status, c1_rec.error_message
                     );

         COMMIT;
         print_log (p_debug_flag, 'No of Records Inserted ' || l_counter);
         print_out ('No of Records Inserted ' || l_counter);
      END LOOP;
   END load_staging;

   PROCEDURE validate_move_order (
      p_debug_flag           IN   VARCHAR2,
      p_contract_number      IN   VARCHAR2,
      p_delivery_id          IN   NUMBER,
      p_delivery_detail_id   IN   NUMBER
   )
   IS
      CURSOR c1
      IS
         SELECT ROWID, xmos.*
           FROM xxav_move_order_stg xmos
          WHERE NVL (error_status, '#') IN ('R')
            AND conc_req_id = g_conc_req_id
            AND contract_number = NVL (p_contract_number, contract_number)
            AND NVL (delivery_id, 0) =
                                     NVL (p_delivery_id, NVL (delivery_id, 0))
            AND delivery_detail_id =
                                NVL (p_delivery_detail_id, delivery_detail_id);

      v_user_id        NUMBER          := fnd_global.user_id;
      v_resp_id        NUMBER          := fnd_global.resp_id;
      v_appl_id        NUMBER          := fnd_global.resp_appl_id;
      v_validate       VARCHAR2 (1);
      v_error_msg      VARCHAR2 (3000);
      v_error_status   VARCHAR2 (1);
   BEGIN
      g_conc_req_id := NULL;
      g_conc_req_id := fnd_global.conc_request_id;
      print_log (p_debug_flag,
                 'Inside the Procedure Validate Move Order ' || g_conc_req_id
                );

      UPDATE xxav_move_order_stg xmos
         SET error_status = 'R',
             error_message = NULL,
             conc_req_id = g_conc_req_id,
             last_update_date = SYSDATE,
             last_updated_by = v_user_id
       WHERE ROWID IN (SELECT ROWID
                         FROM xxav_move_order_stg a
                        WHERE NVL (error_status, 'U') IN ('E', 'U'))
         AND contract_number = NVL (p_contract_number, contract_number)
         AND NVL (delivery_id, 0) = NVL (p_delivery_id, NVL (delivery_id, 0))
         AND delivery_detail_id =
                                NVL (p_delivery_detail_id, delivery_detail_id);

      COMMIT;
      print_log (p_debug_flag, 'After Update of Staging Table ');

      FOR c1_rec IN c1
      LOOP
         print_log
                 (p_debug_flag,
                  'Inside the Loop for Validating the Move Order Information'
                 );
         v_error_status := 'U';
         v_error_msg := NULL;

         --validating the Organization
         BEGIN
            print_log (p_debug_flag,
                          'Validate the Inventory Organization '
                       || c1_rec.organization_id
                      );

            SELECT 'Y'
              INTO v_validate
              FROM org_organization_definitions
             WHERE organization_id = c1_rec.organization_id;
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               v_error_status := 'E';
               print_log (p_debug_flag,
                          'No Organization ' || c1_rec.organization_id
                         );
               v_error_msg :=
                  v_error_msg || ' No Organization ' || c1_rec.organization_id;
            WHEN OTHERS
            THEN
               v_error_status := 'E';
               print_log (p_debug_flag,
                          'Invalid Organization ' || c1_rec.organization_id
                         );
               v_error_msg :=
                     v_error_msg
                  || ' Invalid Organization '
                  || c1_rec.organization_id;
         END;

         -- Validating the Source Sub-Inventory
         print_log (p_debug_flag,
                       'Validate the Source Sub Inventory '
                    || c1_rec.organization_id
                    || ' '
                    || c1_rec.from_subinventory_code
                   );

         BEGIN
            SELECT 'Y'
              INTO v_validate
              FROM mtl_secondary_inventories
             WHERE secondary_inventory_name = c1_rec.from_subinventory_code
               AND organization_id = c1_rec.organization_id;
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               v_error_status := 'E';
               print_log (p_debug_flag,
                             'No Source Sub-Inventory for '
                          || c1_rec.organization_id
                          || ' Source Sub Inventory '
                          || c1_rec.from_subinventory_code
                         );
               v_error_msg :=
                     v_error_msg
                  || ' No Source Sub-Inventory for '
                  || c1_rec.organization_id
                  || ' Source Sub Inventory '
                  || c1_rec.from_subinventory_code;
            WHEN OTHERS
            THEN
               v_error_status := 'E';
               print_log (p_debug_flag,
                             'Invalid Source Sub-Inventory for '
                          || c1_rec.organization_id
                          || ' Source Sub Inventory '
                          || c1_rec.from_subinventory_code
                         );
               v_error_msg :=
                     v_error_msg
                  || ' Invalid Source Sub-Inventory for '
                  || c1_rec.organization_id
                  || ' Source Sub Inventory '
                  || c1_rec.from_subinventory_code;
         END;

         -- Validating the Target Sub-Inventory
         print_log (p_debug_flag,
                       'Validate the To Sub Inventory '
                    || c1_rec.organization_id
                    || ' '
                    || c1_rec.to_subinventory_code
                   );

         BEGIN
            SELECT 'Y'
              INTO v_validate
              FROM mtl_secondary_inventories
             WHERE secondary_inventory_name = c1_rec.to_subinventory_code
               AND organization_id = c1_rec.organization_id;
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               v_error_status := 'E';
               print_log (p_debug_flag,
                             'No Target Sub-Inventory for '
                          || c1_rec.organization_id
                          || ' Target Sub Inventory '
                          || c1_rec.to_subinventory_code
                         );
               v_error_msg :=
                     v_error_msg
                  || ' No Target Sub-Inventory for '
                  || c1_rec.organization_id
                  || ' Target Sub Inventory '
                  || c1_rec.to_subinventory_code;
            WHEN OTHERS
            THEN
               v_error_status := 'E';
               print_log (p_debug_flag,
                             'Invalid Target Sub-Inventory for '
                          || c1_rec.organization_id
                          || ' Target Sub Inventory '
                          || c1_rec.to_subinventory_code
                         );
               v_error_msg :=
                     v_error_msg
                  || ' Invalid Target Sub-Inventory for '
                  || c1_rec.organization_id
                  || ' Target Sub Inventory '
                  || c1_rec.to_subinventory_code;
         END;

         -- Validate the Source Subinventory Locator
         print_log (p_debug_flag,
                       'Validate the From Sub Inventory Locator '
                    || c1_rec.organization_id
                    || ' '
                    || c1_rec.from_subinventory_code
                    || ' '
                    || c1_rec.source_locator
                   );

         BEGIN
            SELECT 'Y'
              INTO v_validate
              FROM mtl_item_locations_kfv
             WHERE concatenated_segments = c1_rec.source_locator
               AND organization_id = c1_rec.organization_id
               AND subinventory_code = c1_rec.from_subinventory_code;
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               v_error_status := 'E';
               print_log (p_debug_flag,
                             'No Source Sub-Inventory Locator for '
                          || c1_rec.organization_id
                          || ' Source Sub Inventory '
                          || c1_rec.from_subinventory_code
                          || ' Locator '
                          || c1_rec.source_locator
                         );
               v_error_msg :=
                     v_error_msg
                  || ' No Source Sub-Inventory Locator for '
                  || c1_rec.organization_id
                  || ' Source Sub Inventory '
                  || c1_rec.from_subinventory_code
                  || ' Locator '
                  || c1_rec.source_locator;
            WHEN OTHERS
            THEN
               v_error_status := 'E';
               print_log (p_debug_flag,
                             'Invalid Source Sub-Inventory Locator for '
                          || c1_rec.organization_id
                          || ' Source Sub Inventory '
                          || c1_rec.from_subinventory_code
                          || ' Locator '
                          || c1_rec.source_locator
                         );
               v_error_msg :=
                     v_error_msg
                  || ' Invalid Source Sub-Inventory for '
                  || c1_rec.organization_id
                  || ' Source Sub Inventory '
                  || c1_rec.from_subinventory_code
                  || ' Locator '
                  || c1_rec.source_locator;
         END;

         -- Validate the Target Subinventory Locator
         print_log (p_debug_flag,
                       'Validate the To Sub Inventory Locator '
                    || c1_rec.organization_id
                    || ' '
                    || c1_rec.to_subinventory_code
                    || ' '
                    || c1_rec.destination_locator
                   );

         BEGIN
            SELECT 'Y'
              INTO v_validate
              FROM mtl_item_locations_kfv
             WHERE concatenated_segments = c1_rec.destination_locator
               AND organization_id = c1_rec.organization_id
               AND subinventory_code = c1_rec.to_subinventory_code;
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               v_error_status := 'E';
               print_log (p_debug_flag,
                             'No Target Sub-Inventory Locator for '
                          || c1_rec.organization_id
                          || ' Target Sub Inventory '
                          || c1_rec.to_subinventory_code
                          || ' '
                          || c1_rec.destination_locator
                         );
               v_error_msg :=
                     v_error_msg
                  || ' No Target Sub-Inventory Locator for '
                  || c1_rec.organization_id
                  || ' Target Sub Inventory '
                  || c1_rec.to_subinventory_code
                  || ' Destination Locator '
                  || c1_rec.destination_locator;
            WHEN OTHERS
            THEN
               v_error_status := 'E';
               print_log (p_debug_flag,
                             'Invalid Target Sub-Inventory for '
                          || c1_rec.organization_id
                          || ' Target Sub Inventory '
                          || c1_rec.to_subinventory_code
                         );
               v_error_msg :=
                     v_error_msg
                  || '  Invalid Target Sub-Inventory for '
                  || c1_rec.organization_id
                  || ' Target Sub Inventory '
                  || c1_rec.to_subinventory_code
                  || ' Destination Locator '
                  || c1_rec.destination_locator;
         END;

         IF v_error_status != 'E'
         THEN
            print_log (p_debug_flag,
                          'Move Order Information Validated '
                       || c1_rec.organization_id
                       || ' Delivery Detail ID '
                       || c1_rec.delivery_detail_id
                      );
            v_error_msg :=
                  v_error_msg
               || ' Move Order Information Validated  '
               || c1_rec.organization_id
               || ' Delivery Detail ID '
               || c1_rec.delivery_detail_id;

            UPDATE xxav_move_order_stg xmos
               SET error_status = 'V',
                   error_message = v_error_msg,
                   conc_req_id = g_conc_req_id,
                   last_update_date = SYSDATE,
                   last_updated_by = v_user_id
             WHERE ROWID = c1_rec.ROWID;
         ELSE
            print_log (p_debug_flag,
                          'Move Order Information Failed for Validation '
                       || c1_rec.organization_id
                       || ' Delivery Detail ID '
                       || c1_rec.delivery_detail_id
                      );
            v_error_msg :=
                  v_error_msg
               || ' Move Order Information Failed for Validation  '
               || c1_rec.organization_id
               || ' Delivery Detail ID '
               || c1_rec.delivery_detail_id;

            UPDATE xxav_move_order_stg xmos
               SET error_status = 'E',
                   error_message = v_error_msg,
                   conc_req_id = g_conc_req_id,
                   last_update_date = SYSDATE,
                   last_updated_by = v_user_id
             WHERE ROWID = c1_rec.ROWID;
         END IF;
      END LOOP;

      COMMIT;
   END validate_move_order;

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
   )
   IS
      l_hdr_rec           inv_move_order_pub.trohdr_rec_type
                                      := inv_move_order_pub.g_miss_trohdr_rec;
      l_line_tbl          inv_move_order_pub.trolin_tbl_type
                                      := inv_move_order_pub.g_miss_trolin_tbl;
      x_hdr_val_rec       inv_move_order_pub.trohdr_val_rec_type;
      x_line_val_tbl      inv_move_order_pub.trolin_val_tbl_type;
      v_msg_index_out     NUMBER;
      l_rsr_type          inv_reservation_global.mtl_reservation_tbl_type;
      l_line_no           NUMBER                                         := 0;
      v_error_status      VARCHAR2 (1);

      CURSOR c1
      IS
         SELECT ROWID, xmos.*
           FROM xxav_move_order_stg xmos
          WHERE NVL (error_status, '#') IN ('R')
            AND conc_req_id = g_conc_req_id
            AND delivery_detail_id = 3963472
            AND contract_number = NVL (p_contract_number, contract_number)
            AND NVL (delivery_id, 0) =
                                     NVL (p_delivery_id, NVL (delivery_id, 0))
            AND delivery_detail_id =
                                NVL (p_delivery_detail_id, delivery_detail_id);

      v_user_id           NUMBER                         := fnd_global.user_id;
      v_resp_id           NUMBER                         := fnd_global.resp_id;
      v_appl_id           NUMBER                    := fnd_global.resp_appl_id;
      v_validate          VARCHAR2 (1);
      v_error_msg         VARCHAR2 (3000);
      v_profile_orgn_id   NUMBER;
      v_profile_org_id    NUMBER;
   BEGIN
      g_conc_req_id := NULL;
      v_error_status := NULL;
      v_error_msg := NULL;
      g_conc_req_id := fnd_global.conc_request_id;

      UPDATE xxav_move_order_stg xmos
         SET error_status = 'R',
             error_message = NULL,
             conc_req_id = g_conc_req_id,
             last_update_date = SYSDATE,
             last_updated_by = v_user_id
       WHERE ROWID IN (SELECT ROWID
                         FROM xxav_move_order_stg a
                        WHERE NVL (error_status, '#') IN ('V'))
         AND contract_number = NVL (p_contract_number, contract_number)
         AND delivery_detail_id = 3963472
         AND NVL (delivery_id, 0) = NVL (p_delivery_id, NVL (delivery_id, 0))
         AND delivery_detail_id =
                                NVL (p_delivery_detail_id, delivery_detail_id);

      COMMIT;
      v_profile_orgn_id := 603;   --fnd_profile.VALUE ('MFG_ORGANIZATION_ID');
      v_profile_org_id := fnd_profile.VALUE ('ORG_ID');
      print_log (p_debug_flag,
                    'Profile Values '
                 || v_user_id
                 || ' v_resp_id '
                 || v_resp_id
                 || ' v_appl_id '
                 || v_appl_id
                 || ' v_profile_org_id '
                 || v_profile_org_id
                 || ' Organization ID '
                 || v_profile_orgn_id
                 || 'Concurrent Request ID '
                 || g_conc_req_id
                );
      mo_global.set_policy_context ('S', v_profile_orgn_id);
      inv_globals.set_org_id (v_profile_org_id);
      fnd_global.apps_initialize (v_user_id, v_resp_id, v_appl_id);
      print_log (p_debug_flag, 'Creating Move Order');

      FOR c1_rec IN c1
      LOOP
         l_line_tbl.DELETE;
         x_line_tbl.DELETE;
         l_hdr_rec.date_required := SYSDATE;
         l_hdr_rec.header_status := inv_globals.g_to_status_preapproved;
         l_hdr_rec.organization_id := c1_rec.organization_id;
         l_hdr_rec.status_date := SYSDATE;
         l_hdr_rec.transaction_type_id :=
                                      inv_globals.g_type_transfer_order_issue;
         l_hdr_rec.move_order_type := inv_globals.g_move_order_requisition;
         l_hdr_rec.db_flag := fnd_api.g_true;
         l_hdr_rec.operation := inv_globals.g_opr_create;
         l_hdr_rec.description := 'Move Order -> ' || SYSDATE;
         l_hdr_rec.to_account_id := 19305;
         l_hdr_rec.from_subinventory_code := c1_rec.from_subinventory_code;
         l_line_tbl (1).date_required := SYSDATE;
         l_line_tbl (1).inventory_item_id := c1_rec.inventory_item_id;
         l_line_tbl (1).line_id := fnd_api.g_miss_num;
         l_line_tbl (1).line_number := l_line_no + 1;
         l_line_tbl (1).line_status := inv_globals.g_to_status_preapproved;
         l_line_tbl (1).transaction_type_id :=
                                      inv_globals.g_type_transfer_order_issue;
         l_line_tbl (1).organization_id := c1_rec.organization_id;
         l_line_tbl (1).quantity := c1_rec.quantity;
         l_line_tbl (1).status_date := SYSDATE;
         l_line_tbl (1).uom_code := c1_rec.uom_code;
         l_line_tbl (1).db_flag := fnd_api.g_true;
         l_line_tbl (1).operation := inv_globals.g_opr_create;
         l_line_tbl (1).from_subinventory_code :=
                                                c1_rec.from_subinventory_code;
         --l_line_tbl (1).from_locator := c1_rec.source_locator;
         --l_line_tbl (1).to_subinventory := c1_rec.to_subinventory_code;
         --l_line_tbl (1).to_locator := c1_rec.destination_locator;
         --l_line_tbl (1).to_account_id := 12831;
         --l_line_tbl (1).lot_number := c1_rec.source_locator;
         --L_line_tbl (1).serial_number_start := 'A010039
         --L_line_tbl (1).serial_number_end := 'A010039';
         print_log (p_debug_flag, 'Before Move Order API ');
         inv_move_order_pub.process_move_order
                                         (p_api_version_number      => 1.0,
                                          p_init_msg_list           => fnd_api.g_false,
                                          p_return_values           => fnd_api.g_false,
                                          p_commit                  => fnd_api.g_false,
                                          x_return_status           => x_return_status,
                                          x_msg_count               => x_msg_count,
                                          x_msg_data                => x_msg_data,
                                          p_trohdr_rec              => l_hdr_rec,
                                          p_trolin_tbl              => l_line_tbl,
                                          x_trohdr_rec              => x_hdr_rec,
                                          x_trohdr_val_rec          => x_hdr_val_rec,
                                          x_trolin_tbl              => x_line_tbl,
                                          x_trolin_val_tbl          => x_line_val_tbl
                                         );
         print_log (p_debug_flag, 'Return Status is :' || x_return_status);
         print_log (p_debug_flag, 'Message Count is :' || x_msg_count);

         IF x_return_status = 'S'
         THEN
            COMMIT;
            print_log (p_debug_flag,
                       'Move Order Number is :' || x_hdr_rec.request_number
                      );
            print_log (p_debug_flag,
                       'Move Order ID is :' || x_hdr_rec.header_id
                      );
            print_log (p_debug_flag,
                       'Number of Lines Created are :' || x_line_tbl.COUNT
                      );
            print_log (p_debug_flag,
                          'Move Order Created  '
                       || c1_rec.organization_id
                       || ' Move Order No '
                       || x_hdr_rec.request_number
                      );
            v_error_msg :=
                  v_error_msg
               || ' Move Order Created  '
               || c1_rec.organization_id
               || ' Move Order No '
               || x_hdr_rec.request_number;
            v_error_status := 'S1';

            UPDATE xxav_move_order_stg xmos
               SET error_status = 'S1',
                   error_message = v_error_msg || ' ' || v_error_msg,
                   last_update_date = SYSDATE,
                   last_updated_by = v_user_id,
                   request_number = x_hdr_rec.request_number,
                   line_number = l_line_no
             WHERE ROWID = c1_rec.ROWID;
         ELSE
            v_error_status := 'E';

            IF x_msg_count > 0
            THEN
               FOR v_index IN 1 .. x_msg_count
               LOOP
                  fnd_msg_pub.get (p_msg_index          => v_index,
                                   p_encoded            => 'F',
                                   p_data               => x_msg_data,
                                   p_msg_index_out      => v_msg_index_out
                                  );
                  x_msg_data := SUBSTR (x_msg_data, 1, 200);
                  print_log (p_debug_flag, x_msg_data);
                  v_error_msg := v_error_msg || ' ' || x_msg_data;
               END LOOP;

            END IF;

            print_log (p_debug_flag,
                          'Error in creating the Move Order '
                       || c1_rec.delivery_detail_id
                      );
            v_error_msg :=
                  v_error_msg
               || 'Error in creating the Move Order '
               || c1_rec.organization_id
               || ' Delivery Detaild ID '
               || c1_rec.delivery_detail_id;

            UPDATE xxav_move_order_stg xmos
               SET error_status = 'E',
                   error_message = v_error_msg || ' ' || v_error_msg,
                   conc_req_id = g_conc_req_id,
                   last_update_date = SYSDATE,
                   last_updated_by = v_user_id
             WHERE ROWID = c1_rec.ROWID;
         END IF;
      END LOOP;

      -- Process started for performing the Allocate Move Order
      print_log (p_debug_flag,
                 'Validating for the Line Records Greater Than 0 '
                );

      BEGIN
         IF l_line_tbl.COUNT > 0 AND v_error_status != 'E'
         THEN
            x_return_status := NULL;
            x_msg_data := NULL;
            x_msg_count := NULL;
            print_log (p_debug_flag,
                       'Process started to Allocate the Move Order'
                      );
            allocate_move_order (p_debug_flag,
                                 l_line_tbl,
                                 x_return_status,
                                 x_msg_data,
                                 x_msg_count
                                );

            IF x_return_status = 'S'
            THEN
               COMMIT;
               print_log (p_debug_flag, 'Move Order Allocated');
               print_log (p_debug_flag,
                             'Move Order Created  '
                          || ' Move Order No '
                          || x_hdr_rec.request_number
                         );
               v_error_msg :=
                     v_error_msg
                  || 'Move Order Created  '
                  || ' Move Order No '
                  || x_hdr_rec.request_number;

               UPDATE xxav_move_order_stg xmos
                  SET error_status = 'S2',
                      error_message = v_error_msg,
                      conc_req_id = g_conc_req_id,
                      last_update_date = SYSDATE,
                      last_updated_by = v_user_id
                WHERE error_status = 'S1'
                  AND contract_number =
                                      NVL (p_contract_number, contract_number)
                  AND delivery_id = NVL (p_delivery_id, delivery_id)
                  AND delivery_detail_id =
                                NVL (p_delivery_detail_id, delivery_detail_id);

               -- Performing the Transact Move Order
               BEGIN
                  x_return_status := NULL;
                  print_log (p_debug_flag, 'Transacting Move Order');
                  print_log (p_debug_flag,
                                'l_header_rec.header_id :'
                             || l_header_rec.header_id
                            );
                  transact_move_order (p_debug_flag,
                                       l_header_rec.header_id,
                                       x_return_status
                                      );

                  IF x_return_status = 'S'
                  THEN
                     UPDATE xxav_move_order_stg xmos
                        SET error_status = 'S',
                            error_message = v_error_msg || ' ' || v_error_msg,
                            conc_req_id = g_conc_req_id,
                            last_update_date = SYSDATE,
                            last_updated_by = v_user_id
                      WHERE error_status = 'S2'
                        AND contract_number =
                                      NVL (p_contract_number, contract_number)
                        AND delivery_id = NVL (p_delivery_id, delivery_id)
                        AND delivery_detail_id =
                                NVL (p_delivery_detail_id, delivery_detail_id);

                     COMMIT;
                     print_log (p_debug_flag, 'Move Order Transacted');
                  ELSE
                     print_log (p_debug_flag,
                                   'Error in Transacting the Move Order '
                                || p_delivery_detail_id
                               );
                     v_error_msg :=
                           v_error_msg
                        || ' Error in Transacting the Move Order '
                        || ' Delivery Detaild ID '
                        || p_delivery_detail_id;

                     UPDATE xxav_move_order_stg xmos
                        SET error_status = 'E',
                            error_message = v_error_msg || ' ' || v_error_msg,
                            conc_req_id = g_conc_req_id,
                            last_update_date = SYSDATE,
                            last_updated_by = v_user_id
                      WHERE error_status = 'S2'
                        AND contract_number =
                                      NVL (p_contract_number, contract_number)
                        AND delivery_id = NVL (p_delivery_id, delivery_id)
                        AND delivery_detail_id =
                                NVL (p_delivery_detail_id, delivery_detail_id);
                  END IF;
               END;
            ELSE
               print_log (p_debug_flag,
                             'Error in Allocating the Move Order '
                          || p_delivery_detail_id
                         );
               v_error_msg :=
                     v_error_msg
                  || ' Error in Allocating the Move Order '
                  || ' Delivery Detaild ID '
                  || p_delivery_detail_id;

               UPDATE xxav_move_order_stg xmos
                  SET error_status = 'E',
                      error_message = v_error_msg || ' ' || v_error_msg,
                      conc_req_id = g_conc_req_id,
                      last_update_date = SYSDATE,
                      last_updated_by = v_user_id
                WHERE error_status = 'S1'
                  AND contract_number =
                                      NVL (p_contract_number, contract_number)
                  AND delivery_id = NVL (p_delivery_id, delivery_id)
                  AND delivery_detail_id =
                                NVL (p_delivery_detail_id, delivery_detail_id);
            END IF;
         ELSE
            print_log (p_debug_flag,
                          'Error in Creating the Move Order Lines'
                       || p_delivery_detail_id
                      );
            v_error_msg :=
                  v_error_msg
               || ' Error in Creating the Move Order Lines'
               || ' Delivery Detaild ID '
               || p_delivery_detail_id;

            UPDATE xxav_move_order_stg xmos
               SET error_status = 'E',
                   error_message = v_error_msg || ' ' || v_error_msg,
                   conc_req_id = g_conc_req_id,
                   last_update_date = SYSDATE,
                   last_updated_by = v_user_id
             WHERE error_status = 'V'
               AND contract_number = NVL (p_contract_number, contract_number)
               AND delivery_id = NVL (p_delivery_id, delivery_id)
               AND delivery_detail_id =
                                NVL (p_delivery_detail_id, delivery_detail_id);
         END IF;

         COMMIT;
         -- Call the notification mailer program to send the Mail
         print_log (p_debug_flag,
                    'Sending Mail for Conc Request ID ' || g_conc_req_id
                   );
         get_con_id (g_conc_req_id);
      END;
   END execute_move_order;

   PROCEDURE allocate_move_order (
      p_debug_flag      IN       VARCHAR2,
      p_line_tbl        IN       inv_move_order_pub.trolin_tbl_type,
      x_return_status   OUT      VARCHAR2,
      x_msg_data        OUT      VARCHAR2,
      x_msg_count       OUT      NUMBER
   )
   IS
      x_line_tbl        inv_move_order_pub.trolin_tbl_type;
      l_trolin_tbl      inv_move_order_pub.trolin_tbl_type;
      l_mold_tbl        inv_mo_line_detail_util.g_mmtt_tbl_type;
      l_qty_detailed    NUMBER;
      l_qty_delivered   NUMBER;
      l_return_status   VARCHAR2 (1);
      v_msg_index_out   NUMBER;
      l_rsr_type        inv_reservation_global.mtl_reservation_tbl_type;
      i                 INTEGER;
      l_trolin_rec      inv_move_order_pub.trolin_rec_type;
   BEGIN
      x_line_tbl := p_line_tbl;

      IF x_line_tbl.COUNT > 0
      THEN
         FOR j IN x_line_tbl.FIRST .. x_line_tbl.LAST
         LOOP
            print_log (p_debug_flag, x_line_tbl (j).line_id);

            BEGIN
               inv_ppengine_pvt.create_suggestions
                           (p_api_version              => 1.0,
                            p_init_msg_list            => fnd_api.g_false,
                            p_commit                   => fnd_api.g_false,
                            p_validation_level         => fnd_api.g_valid_level_none,
                            x_return_status            => x_return_status,
                            x_msg_count                => x_msg_count,
                            x_msg_data                 => x_msg_data,
                            p_transaction_temp_id      => x_line_tbl (j).line_id,
                            p_reservations             => l_rsr_type,
                            p_suggest_serial           => fnd_api.g_true,
                            p_plan_tasks               => FALSE,
                            p_quick_pick_flag          => 'N',
                            p_organization_id          => 207
                           );
               print_log (p_debug_flag,
                          'Return Status is :' || x_return_status
                         );
               print_log (p_debug_flag, 'Message Count is :' || x_msg_count);

               IF x_return_status = 'S'
               THEN
                  BEGIN
                     l_trolin_tbl := x_line_tbl;

                     IF (l_trolin_tbl.COUNT != 0)
                     THEN
                        i := l_trolin_tbl.FIRST;

                        WHILE i IS NOT NULL
                        LOOP
                           IF (    l_trolin_tbl (i).return_status !=
                                                 fnd_api.g_ret_sts_unexp_error
                               AND l_trolin_tbl (i).return_status !=
                                                       fnd_api.g_ret_sts_error
                              )
                           THEN
                              l_trolin_rec :=
                                 inv_trolin_util.query_row
                                                     (l_trolin_tbl (i).line_id
                                                     );
                              l_trolin_tbl (i) := l_trolin_rec;
                              l_qty_detailed :=
                                            l_trolin_tbl (i).quantity_detailed;
                              l_qty_delivered :=
                                  NVL (l_trolin_tbl (i).quantity_delivered, 0);

                              IF NVL (l_qty_detailed, 0) = 0
                              THEN
                                 l_mold_tbl :=
                                    inv_mo_line_detail_util.query_rows
                                        (p_line_id      => l_trolin_tbl (i).line_id
                                        );

                                 FOR j IN 1 .. l_mold_tbl.COUNT
                                 LOOP
                                    l_mold_tbl (j).transaction_status := 3;
                                    l_mold_tbl (j).transaction_mode := 1;
                                    l_mold_tbl (j).source_line_id :=
                                                     l_trolin_tbl (i).line_id;
                                    inv_mo_line_detail_util.update_row
                                                            (l_return_status,
                                                             l_mold_tbl (j)
                                                            );
                                 END LOOP;

                                 SELECT transaction_header_id,
                                        transaction_quantity
                                   INTO l_trolin_tbl (i).transaction_header_id,
                                        l_trolin_tbl (i).quantity_detailed
                                   FROM mtl_material_transactions_temp
                                  WHERE move_order_line_id =
                                                      l_trolin_tbl (i).line_id;

                                 l_trolin_tbl (i).last_update_date := SYSDATE;
                                 l_trolin_tbl (i).last_update_login :=
                                                           fnd_global.login_id;

                                 IF l_trolin_tbl (i).last_update_login = -1
                                 THEN
                                    l_trolin_tbl (i).last_update_login :=
                                                     fnd_global.conc_login_id;
                                 END IF;

                                 l_trolin_tbl (i).last_updated_by :=
                                                            fnd_global.user_id;
                                 l_trolin_tbl (i).program_id :=
                                                    fnd_global.conc_program_id;
                                 l_trolin_tbl (i).program_update_date :=
                                                                       SYSDATE;
                                 l_trolin_tbl (i).request_id :=
                                                    fnd_global.conc_request_id;
                                 l_trolin_tbl (i).program_application_id :=
                                                       fnd_global.prog_appl_id;
                                 inv_trolin_util.update_row (l_trolin_tbl (i));
                              END IF;
                           END IF;

                           i := l_trolin_tbl.NEXT (i);
                        END LOOP;
                     END IF;
                  END;
               ELSE
                  ROLLBACK;
               END IF;

               IF x_msg_count > 0
               THEN
                  FOR v_index IN 1 .. x_msg_count
                  LOOP
                     fnd_msg_pub.get (p_msg_index          => v_index,
                                      p_encoded            => 'F',
                                      p_data               => x_msg_data,
                                      p_msg_index_out      => v_msg_index_out
                                     );
                     x_msg_data := SUBSTR (x_msg_data, 1, 200);
                     print_log (p_debug_flag, x_msg_data);
                  END LOOP;
               END IF;
            END;
         END LOOP;
      END IF;
   END allocate_move_order;

   PROCEDURE transact_move_order (
      p_debug_flag      IN       VARCHAR2,
      p_move_order_id   IN       NUMBER,
      x_return_status   OUT      VARCHAR2
   )
   IS
      l_header_id        NUMBER;
      l_program          VARCHAR2 (100);
      l_func             VARCHAR2 (100);
      l_args             VARCHAR2 (100);
      p_timeout          NUMBER;
      l_old_tm_success   BOOLEAN;
      l_rc_field         NUMBER;

      CURSOR c1 (p_header_id IN NUMBER)
      IS
         SELECT transaction_header_id
           FROM mtl_material_transactions_temp
          WHERE transaction_source_id = p_header_id;
   BEGIN
      FOR i IN c1 (p_move_order_id)
      LOOP
         l_program := 'INXTPU';
         l_func := l_program;
         l_args :=
               l_program
            || ' '
            || 'TRANS_HEADER_ID='
            || TO_CHAR (i.transaction_header_id);
         p_timeout := 500;
         COMMIT;
         l_old_tm_success :=
            inv_pick_wave_pick_confirm_pub.inv_tm_launch
                                                        (program      => l_program,
                                                         args         => l_args,
                                                         TIMEOUT      => p_timeout,
                                                         rtval        => l_rc_field
                                                        );

         IF l_old_tm_success
         THEN
            x_return_status := 'S';
            print_log (p_debug_flag, 'Result is :' || 'Success');
         ELSE
            x_return_status := 'E';
            print_log (p_debug_flag, 'Result is :' || 'Failed');
         END IF;

         IF x_return_status = 'S'
         THEN
            COMMIT;
         ELSE
            ROLLBACK;
         END IF;
      END LOOP;
   END transact_move_order;

   PROCEDURE get_con_id (p_request_id NUMBER)
   AS
   BEGIN
      g_request_id := p_request_id;
      get_log_out (g_request_id);
   END;

   PROCEDURE get_log_out (p_lo_req_id NUMBER)
   AS
      l_logfile_name   VARCHAR2 (255);
      l_outfile_name   VARCHAR2 (345);
      l_log_files      VARCHAR2 (345);
      l_out_files      VARCHAR2 (345);
      log_fname        VARCHAR2 (345);
      out_fname        VARCHAR2 (345);
   BEGIN
      SELECT logfile_name, outfile_name
        INTO l_logfile_name, l_outfile_name
        FROM fnd_concurrent_requests
       WHERE request_id = p_lo_req_id;

      SELECT SUBSTR (l_logfile_name, INSTR (l_logfile_name, '/', -1) + 1)
        INTO log_fname
        FROM (SELECT l_logfile_name
                FROM fnd_concurrent_requests
               WHERE request_id = p_lo_req_id);

      l_log_files := log_fname;

      --print_log (p_debug_flag, l_log_files);

      ---------------------
      SELECT SUBSTR (l_outfile_name, INSTR (l_outfile_name, '/', -1) + 1)
        INTO out_fname
        FROM (SELECT l_outfile_name
                FROM fnd_concurrent_requests
               WHERE request_id = p_lo_req_id);

      l_out_files := out_fname;
   --print_log (p_debug_flag, l_out_files);
   --read_log_out (l_log_files, l_out_files);
   END;

   PROCEDURE read_log_out (p_log_fname VARCHAR2, p_out_fname VARCHAR2)
   IS
      log_contents   VARCHAR2 (32767);
      out_contents   VARCHAR2 (32767);
      file_log       BFILE         := BFILENAME ('LOG_CON_FILE', p_log_fname);
      file_out       BFILE         := BFILENAME ('OUT_CON_FILE', p_out_fname);
   BEGIN
      DBMS_LOB.fileopen (file_log, DBMS_LOB.file_readonly);
      log_contents := UTL_RAW.cast_to_varchar2 (DBMS_LOB.SUBSTR (file_log));
      print_log ('Y', p_log_fname);
      DBMS_LOB.CLOSE (file_log);
      DBMS_LOB.fileopen (file_out, DBMS_LOB.file_readonly);
      out_contents := UTL_RAW.cast_to_varchar2 (DBMS_LOB.SUBSTR (file_out));
      print_log ('Y', p_out_fname);
      DBMS_LOB.CLOSE (file_out);
      send_logout_mail (log_contents, out_contents);
   END;

   PROCEDURE send_logout_mail (
      p_attach_log   IN   CLOB DEFAULT NULL,
      p_attach_out   IN   CLOB DEFAULT NULL
   )
   AS
      l_mail_conn      UTL_SMTP.connection;
      l_boundary       VARCHAR2 (50)       := '----=*#abc1234321cba#*=';
      l_step           PLS_INTEGER         := 12000;
      -- make sure you set a multiple of 3 not higher than 24573
      p_to             VARCHAR2 (250)      := 'muru@quadrobay.com';
      p_from           VARCHAR2 (250)      := 'suganya@quadrobay.com';
      p_subject        VARCHAR2 (250)
                       := 'Concurrent Request ID is' || '   ' || g_request_id;
      p_text_msg       VARCHAR2 (250)
         := 'The attachment contain output and log files of the corresponding concurrent request id';
      p_attach_name    VARCHAR2 (5000)     := 'log.txt';
      p_attach_name1   VARCHAR2 (5000)     := 'out.txt';
      p_attach_mime    VARCHAR2 (250)      := 'text/plain';
      p_smtp_host      VARCHAR2 (250)      := 'mail.quadrobay.com';
      p_smtp_port      NUMBER              DEFAULT 25;
   BEGIN
      l_mail_conn := UTL_SMTP.open_connection (p_smtp_host, p_smtp_port);
      UTL_SMTP.helo (l_mail_conn, p_smtp_host);
      UTL_SMTP.mail (l_mail_conn, p_from);
      UTL_SMTP.rcpt (l_mail_conn, p_to);
      UTL_SMTP.open_data (l_mail_conn);
      UTL_SMTP.write_data (l_mail_conn,
                              'Date: '
                           || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                           || UTL_TCP.crlf
                          );
      UTL_SMTP.write_data (l_mail_conn, 'To: ' || p_to || UTL_TCP.crlf);
      UTL_SMTP.write_data (l_mail_conn, 'From: ' || p_from || UTL_TCP.crlf);
      UTL_SMTP.write_data (l_mail_conn,
                           'Subject: ' || p_subject || UTL_TCP.crlf
                          );
      UTL_SMTP.write_data (l_mail_conn,
                           'Reply-To: ' || p_from || UTL_TCP.crlf);
      UTL_SMTP.write_data (l_mail_conn, 'MIME-Version: 1.0' || UTL_TCP.crlf);
      UTL_SMTP.write_data (l_mail_conn,
                              'Content-Type: multipart/mixed; boundary="'
                           || l_boundary
                           || '"'
                           || UTL_TCP.crlf
                           || UTL_TCP.crlf
                          );

      IF p_text_msg IS NOT NULL
      THEN
         UTL_SMTP.write_data (l_mail_conn,
                              '--' || l_boundary || UTL_TCP.crlf);
         UTL_SMTP.write_data
                         (l_mail_conn,
                             'Content-Type: text/plain; charset="iso-8859-1"'
                          || UTL_TCP.crlf
                          || UTL_TCP.crlf
                         );
         UTL_SMTP.write_data (l_mail_conn, p_text_msg);
         UTL_SMTP.write_data (l_mail_conn, UTL_TCP.crlf || UTL_TCP.crlf);
      END IF;

      IF p_attach_name IS NOT NULL
      THEN
         UTL_SMTP.write_data (l_mail_conn,
                              '--' || l_boundary || UTL_TCP.crlf);
         UTL_SMTP.write_data (l_mail_conn,
                                 'Content-Type: '
                              || p_attach_mime
                              || '; name="'
                              || p_attach_name
                              || '"'
                              || UTL_TCP.crlf
                             );
         UTL_SMTP.write_data (l_mail_conn,
                                 'Content-Disposition: attachment; filename="'
                              || p_attach_name
                              || '"'
                              || UTL_TCP.crlf
                              || UTL_TCP.crlf
                             );

         FOR i IN 0 .. TRUNC ((DBMS_LOB.getlength (p_attach_log) - 1) / l_step)
         LOOP
            UTL_SMTP.write_data (l_mail_conn,
                                 DBMS_LOB.SUBSTR (p_attach_log,
                                                  l_step,
                                                  i * l_step + 1
                                                 )
                                );
         END LOOP;
      END IF;

      IF p_attach_name1 IS NOT NULL
      THEN
         UTL_SMTP.write_data (l_mail_conn,
                              '--' || l_boundary || UTL_TCP.crlf);
         UTL_SMTP.write_data (l_mail_conn,
                                 'Content-Type: '
                              || p_attach_mime
                              || '; name="'
                              || p_attach_name1
                              || '"'
                              || UTL_TCP.crlf
                             );
         UTL_SMTP.write_data (l_mail_conn,
                                 'Content-Disposition: attachment; filename="'
                              || p_attach_name1
                              || '"'
                              || UTL_TCP.crlf
                              || UTL_TCP.crlf
                             );

         FOR i IN 0 .. TRUNC ((DBMS_LOB.getlength (p_attach_out) - 1) / l_step)
         LOOP
            UTL_SMTP.write_data (l_mail_conn,
                                 DBMS_LOB.SUBSTR (p_attach_out,
                                                  l_step,
                                                  i * l_step + 1
                                                 )
                                );
         END LOOP;

         UTL_SMTP.write_data (l_mail_conn, UTL_TCP.crlf || UTL_TCP.crlf);
      END IF;

      UTL_SMTP.write_data (l_mail_conn,
                           '--' || l_boundary || '--' || UTL_TCP.crlf
                          );
      UTL_SMTP.close_data (l_mail_conn);
      UTL_SMTP.quit (l_mail_conn);
   --print_log (p_debug_flag, p_subject);
   END;
END xxav_move_order_pkg;