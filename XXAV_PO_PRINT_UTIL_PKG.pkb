create or replace PACKAGE BODY XXAV_PO_PRINT_UTIL_PKG
IS
--==================================================   
  /*
  
  PROCEDURE insert_articles(p_po_header_id number) IS
  
  BEGIN
  -- This procedure shall be called in before report trigger
     null;
     --Extract articles for Contract
     insert into xxav_po_print_articles_temp
     ( po_header_id,line_num  ,comm_noncomm ,project_number ,task_number ,article_name ,article_text)
            values (p_po_header_id, ' 1,2,3,4,5,6', 'Commercial', 'Test Project', 'Test Task1', 'Article1', 'Article Description 1');
     insert into xxav_po_print_articles_temp
     ( po_header_id,line_num  ,comm_noncomm ,project_number ,task_number ,article_name ,article_text)
            values (p_po_header_id, ' 1,2,3,5,6', 'Commercial', 'Test Project', 'Test Task2', 'Article2', 'Article Description 2');
     insert into xxav_po_print_articles_temp
     ( po_header_id,line_num  ,comm_noncomm ,project_number ,task_number ,article_name ,article_text)
            values (p_po_header_id, ' 1,3,6', 'Commercial', 'Test Project', 'Test Task2', 'Article3', 'Article Description 3');
     insert into xxav_po_print_articles_temp
     ( po_header_id,line_num  ,comm_noncomm ,project_number ,task_number ,article_name ,article_text)
            values (p_po_header_id, ' 1,2,6', 'Non-Commercial', 'Test Project', 'Test Task3', 'Article4', 'Article Description 4');
     insert into xxav_po_print_articles_temp
     ( po_header_id,line_num  ,comm_noncomm ,project_number ,task_number ,article_name ,article_text)
            values (p_po_header_id, ' 3,4,5,6', 'Non-Commercial', 'Test Project', 'Test Task4', 'Article5', 'Article Description 5');
     insert into xxav_po_print_articles_temp
     ( po_header_id,line_num  ,comm_noncomm ,project_number ,task_number ,article_name ,article_text)
            values (p_po_header_id, ' 2,3,4,', 'Non-Commercial', 'Test Project', 'Test Task5', 'Article6', 'Article Description 6');
     --Extract articles for BOA Contract (Master Agreement)
     --insert into xxav_po_print_articles_temp
     commit;
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG, 'Error : ' || SQLERRM);
   END insert_articles;
   */
   
   PROCEDURE insert_articles(p_po_header_id number)
AS
  CURSOR c1
  IS
    SELECT pha.po_header_id, pla.line_num,DECODE(msi.revision_qty_control_code,1,'Commercial',2,'NonCommercial') commnoncomm
    ,ppa.segment1 project_number, pt.task_number, okav.NAME  ,okhfv.k_header_id,okav.sav_sae_id,okav.sav_sav_release
    FROM po_headers_all pha,
         po_lines_all pla,
         po_line_locations_all plla,
         po_distributions_all pda,
         mtl_system_items_b msi,
         oke_k_headers_full_v okhfv,
         oke_k_lines_full_v oklfv,
         oke_k_articles_v okav,
         pa_projects_all ppa,
         pa_tasks pt,
         okc.okc_articles_all c
   WHERE     pha.po_header_id = pla.po_header_id
         AND pla.po_line_id = plla.po_line_id
         AND plla.line_location_id = pda.line_location_id
         AND pla.item_id = msi.inventory_item_id
         AND okhfv.k_header_id = oklfv.header_id
         AND pda.project_id = oklfv.project_id
         AND oklfv.project_id = ppa.project_id
         AND ppa.project_id = pt.project_id
         AND pda.task_id = pt.task_id
         AND pha.po_header_id = p_po_header_id
         AND msi.organization_id =
                (SELECT master_organization_id
                   FROM mtl_parameters
                  WHERE organization_id = plla.ship_to_organization_id)
         AND okhfv.k_header_id = okav.dnz_chr_id
         AND okav.sav_sae_id = c.article_id(+)
         AND okav.sbt_code LIKE '%FLOWDOWN%'
         AND okav.sav_sav_release IS NULL
         AND oklfv.header_id = okhfv.k_header_id
         --and oklfv.project_id = :project_id
    /* AND ppa.segment1 = :project
     AND okav.NAME = :article
     AND pt.task_number = :task_number
     AND DECODE (msi.revision_qty_control_code,
                 1, 'Commercial',
                 2, 'NonCommercial'
                ) = :commnoncomm_*/
         AND pha.po_header_id = p_po_header_id
GROUP BY okav.NAME,
         msi.revision_qty_control_code,
         ppa.segment1,
         pt.task_number,
         pha.po_header_id, pla.line_num,okhfv.k_header_id,okav.sav_sae_id,okav.sav_sav_release
UNION
  SELECT pha.po_header_id, pla.line_num,
         DECODE (msi.revision_qty_control_code,
                 1, 'Commercial',
                 2, 'NonCommercial'
                ) "commnoncomm",
         ppa.segment1 project, pt.task_number, okav.NAME article,okhfv.k_header_id,okav.sav_sae_id,okav.sav_sav_release
    FROM po_headers_all pha,
         po_lines_all pla,
         po_line_locations_all plla,
         po_distributions_all pda,
         mtl_system_items_b msi,
         oke_k_headers_full_v okhfv,
         oke_k_lines_full_v oklfv,
         oke_k_articles_v okav,
         pa_projects_all ppa,
         pa_tasks pt,
         okc.okc_articles_all c,
         OKC_ARTICLE_VERSIONS AV
   WHERE     pha.po_header_id = pla.po_header_id
         AND pla.po_line_id = plla.po_line_id
         AND plla.line_location_id = pda.line_location_id
         AND pla.item_id = msi.inventory_item_id
         AND okhfv.k_header_id = oklfv.header_id
         AND pda.project_id = oklfv.project_id
         AND oklfv.project_id = ppa.project_id
         AND ppa.project_id = pt.project_id
         AND pda.task_id = pt.task_id
         AND pha.po_header_id = p_po_header_id
         AND msi.organization_id =
                (SELECT master_organization_id
                   FROM mtl_parameters
                  WHERE organization_id = plla.ship_to_organization_id)
         AND okhfv.k_header_id = okav.dnz_chr_id
         AND okav.sav_sae_id = c.article_id
         AND okav.sbt_code LIKE '%FLOWDOWN%'
         AND C.ARTICLE_ID = AV.ARTICLE_ID
         AND NVL (AV.ATTRIBUTE3, 'N') = 'N'
         and msi.revision_qty_control_code = 1
         AND AV.article_language = 'US'
         AND okav.sav_sav_release = AV.ARTICLE_VERSION_NUMBER
         AND oklfv.header_id = okhfv.k_header_id
    /* AND ppa.segment1 = :project
     AND okav.NAME = :article
     AND pt.task_number = :task_number
     AND DECODE (msi.revision_qty_control_code,
                 1, 'Commercial',
                 2, 'NonCommercial'
                ) = :commnoncomm_*/
         AND pha.po_header_id = p_po_header_id
GROUP BY okav.NAME,
         msi.revision_qty_control_code,
         ppa.segment1,
         pt.task_number,
         pha.po_header_id,oklfv.project_id, pla.line_num,okhfv.k_header_id,okav.sav_sae_id,okav.sav_sav_release
UNION
  SELECT pha.po_header_id, pla.line_num,
         DECODE (msi.revision_qty_control_code,
                 1, 'Commercial',
                 2, 'NonCommercial'
                ) "commnoncomm",
         ppa.segment1 project, pt.task_number, okav.NAME article,okhfv.k_header_id,okav.sav_sae_id,okav.sav_sav_release
    FROM po_headers_all pha,
         po_lines_all pla,
         po_line_locations_all plla,
         po_distributions_all pda,
         mtl_system_items_b msi,
         oke_k_headers_full_v okhfv,
         oke_k_lines_full_v oklfv,
         oke_k_articles_v okav,
         pa_projects_all ppa,
         pa_tasks pt,
         okc.okc_articles_all c,
         OKC_ARTICLE_VERSIONS AV
   WHERE     pha.po_header_id = pla.po_header_id
         AND pla.po_line_id = plla.po_line_id
         AND plla.line_location_id = pda.line_location_id
         AND pla.item_id = msi.inventory_item_id
         AND okhfv.k_header_id = oklfv.header_id
         AND pda.project_id = oklfv.project_id
         AND oklfv.project_id = ppa.project_id
         AND ppa.project_id = pt.project_id
         AND pda.task_id = pt.task_id
         AND pha.po_header_id = p_po_header_id
         AND msi.organization_id =
                (SELECT master_organization_id
                   FROM mtl_parameters
                  WHERE organization_id = plla.ship_to_organization_id)
         AND okhfv.k_header_id = okav.dnz_chr_id
         AND C.ARTICLE_ID = AV.ARTICLE_ID
         AND okav.sav_sae_id = c.article_id(+)
         AND okav.sbt_code LIKE '%FLOWDOWN%'
         AND NVL (AV.ATTRIBUTE4, 'N') = 'N'
         and msi.revision_qty_control_code = 2
         AND AV.article_language = 'US'
         AND okav.sav_sav_release = AV.ARTICLE_VERSION_NUMBER
         AND oklfv.header_id = okhfv.k_header_id
     /*AND ppa.segment1 = :project
     AND okav.NAME = :article
     AND pt.task_number = :task_number
     AND DECODE (msi.revision_qty_control_code,
                 1, 'Commercial',
                 2, 'NonCommercial'
                ) = :commnoncomm_*/
         AND pha.po_header_id = p_po_header_id
GROUP BY okav.NAME,
         msi.revision_qty_control_code,
         ppa.segment1,
         pt.task_number,
         pha.po_header_id, pla.line_num,okhfv.k_header_id,okav.sav_sae_id,okav.sav_sav_release
ORDER BY 1, 2, 3, 4, 5;

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
  --DELETE   FROM xxav_po_print_articles_temp;

/*
  FOR c_rec IN c1
  LOOP
    v_po_header_id    :=c_rec.po_header_id;
    v_line_num        :='1,2,3,4,5';
    v_comm_noncom     :=c_rec.commnoncomm;
    v_project_number  :=c_rec.project_number;
    v_task_number     :=c_rec.task_number;
    --v_contract_number :=c_rec.k_number;
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
          c1.po_header_id,
          c1.line_num,
          c1.commnoncomm,
          c1.project_number,
          c1.task_number,
          c1.article_name,
          null
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
  
  pha.po_header_id, pla.line_num,DECODE(msi.revision_qty_control_code,1,'Commercial',2,'NonCommercial') commnoncomm
    ,ppa.segment1 project_number, pt.task_number, okav.NAME  ,okhfv.k_header_id,okav.sav_sae_id,okav.sav_sav_release
  */
  
  FOR c1_rec in c1
  LOOP
  INSERT INTO xxav_po_print_articles_temp
        (
          po_header_id,
          line_num ,
          comm_noncomm ,
          project_number ,
          task_number,
          article_name ,
          article_text,
          request_id
        )
        VALUES
        (
          c1_rec.po_header_id,
          c1_rec.line_num,
          c1_rec.commnoncomm,
          c1_rec.project_number,
          c1_rec.task_number,
          c1_rec.name,
          NULL,
          fnd_global.conc_request_id
        );
  end loop;
  
  COMMIT;
  exception
  when others then
  fnd_file.put_line(fnd_file.log,'error');
END insert_articles;

function get_contract_number (p_requisition_line_id number) return varchar2 is

begin
   return '999999';
   
   
   /*
   select k.k_number_disp Contract, p1.segment1 Master_Project, kl2.line_number Contract_Line, 
 p2.segment1 Project, t1.task_number Top_Task, t2.task_id Task_ID, t2.task_number
from oke.oke_k_headers k,
 oke.oke_k_lines kl1, okc.okc_k_lines_b kl2,
 pa.pa_projects_all p1, pa_projects_all p2, pa.pa_tasks t1, pa.pa_tasks t2
where k.project_id = p1.project_id
and k.k_header_id = kl2.chr_id
and kl1.k_line_id = kl2.id
and kl1.project_id = p2.project_id (+)
and kl1.task_id = t1.task_id(+)
and t1.task_id = t2.top_task_id(+)
and kl1.project_id  -- = 636098

in (select project_id from PO_REQ_DISTRIBUTIONS_ALL where …..)

*/
exception
  when others then
  return null;
end;

PROCEDURE delete_articles(p_request_id number) IS
begin
   delete xxav_po_print_articles_temp where request_id = p_request_id;
   
   commit;
   
exception
  when others then
   null;
end;

END XXAV_PO_PRINT_UTIL_PKG;