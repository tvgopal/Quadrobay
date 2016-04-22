CREATE OR REPLACE
PROCEDURE XXAV_PO_PRINT_UTIL(p_po_header_id number)
AS
  CURSOR c1
  IS
    SELECT pha.po_header_id,
      --pla.line_num,
      DECODE (msi.revision_qty_control_code, 1, 'Commercial', 2, 'NonCommercial' ) commnoncomm,
      ppa.segment1 project_number ,
      pt.task_number,
      k_number
    FROM po_headers_all pha,
      po_lines_all pla ,
      po_line_locations_all plla ,
      po_distributions_all pda,
      mtl_system_items_b msi,
      pa_projects_all ppa,
      pa_tasks pt,
      oke_k_headers_full_v curr_contract,
      oke_k_articles_v curr_articles
    WHERE pha.po_header_id    = pla.po_header_id
    AND pla.po_line_id        = plla.po_line_id
    AND plla.line_location_id =pda.line_location_id
    AND pla.item_id           =msi.inventory_item_id
    AND organization_id       =
      (SELECT master_organization_id
      FROM mtl_parameters
      WHERE organization_id = plla.ship_to_organization_id
      )
  AND pda.project_id            = ppa.project_id
  AND pda.task_id               = pt.task_id
  AND curr_contract.k_header_id =curr_articles.chr_id
  AND curr_contract.k_number    =pha.attribute5
  --AND pha.segment1              ='17865'
  AND pha.po_header_id =p_po_header_id
  GROUP BY pha.po_header_id,
    msi.revision_qty_control_code,
    ppa.segment1,
    pt.task_number,
    k_number;
  v_po_header_id    NUMBER;
  v_line_num        VARCHAR2(256);
  v_comm_noncom     VARCHAR2(30);
  v_project_number  VARCHAR2(30);
  v_task_number     VARCHAR2(30);
  v_contract_number VARCHAR2(256);
  v_article_name    VARCHAR2(256);
  v_article_text    VARCHAR2(4000);
  v_boa_id          VARCHAR2(256);
BEGIN
  DELETE
  FROM xxav_po_print_articles_temp;
  FOR c_rec IN c1
  LOOP
    v_po_header_id    :=c_rec.po_header_id;
    v_line_num        :='1,2,3,4,5';
    v_comm_noncom     :=c_rec.commnoncomm;
    v_project_number  :=c_rec.project_number;
    v_task_number     :=c_rec.task_number;
    v_contract_number :=c_rec.k_number;
    --v_article_name
    --v_article_text
    FOR c_rec1 IN
    (SELECT name,
      text,
      boa_id
    FROM oke_k_headers_full_v curr_contract,
      oke_k_articles_v curr_articles
    WHERE curr_contract.k_header_id =curr_articles.chr_id
    AND k_number                    =v_contract_number
    )
    LOOP
      INSERT
      INTO xxav_po_print_articles_temp
        (
          po_header_id,
          line_num ,
          comm_noncomm ,
          project_number ,
          task_number,
          article_name ,
          article_text
        )
        VALUES
        (
          v_po_header_id,
          v_line_num,
          v_comm_noncom,
          v_project_number,
          v_task_number,
          c_rec1.name,
          c_rec1.text
        );
      v_boa_id :=c_rec1.boa_id;
    END LOOP;
    FOR c_rec2 IN
    (SELECT name,
        text
      FROM oke_k_headers_full_v boa_contract,
        oke_k_articles_v boa_articles
      WHERE boa_contract.k_header_id =boa_articles.chr_id
      AND boa_contract.k_header_id   =v_boa_id
    )
    LOOP
      INSERT
      INTO xxav_po_print_articles_temp
        (
          po_header_id,
          line_num ,
          comm_noncomm ,
          project_number ,
          task_number,
          article_name ,
          article_text
        )
        VALUES
        (
          v_po_header_id,
          v_line_num,
          v_comm_noncom,
          v_project_number,
          v_task_number,
          c_rec2.name,
          c_rec2.text
        );
    END LOOP;
  END LOOP;
  COMMIT;
  exception
  when others then
  fnd_file.put_line(fnd_file.log,'error');
END;