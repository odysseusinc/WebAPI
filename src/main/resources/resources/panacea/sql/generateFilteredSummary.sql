--recreate #_pnc_smry_msql_cmb for making the filtered version tasklet run (not created from generateSummary script)
---------------collapse/merge multiple rows to concatenate strings (JSON string for conceptsArrary and conceptsName) ------
IF OBJECT_ID('tempdb..#_pnc_smry_msql_cmb', 'U') IS NOT NULL
  DROP TABLE #_pnc_smry_msql_cmb;
 
CREATE TABLE #_pnc_smry_msql_cmb
(
    pnc_tx_stg_cmb_id int,
    conceptsArray varchar(4000),
	conceptsName varchar(4000)
-- TODO: test this (4000 should be enough for one combo)
--    conceptsArray text,
--	conceptsName text    
);

insert into #_pnc_smry_msql_cmb (pnc_tx_stg_cmb_id, conceptsArray, conceptsName)
select comb_id,  conceptsArray, conceptsName 
from
(
	select comb.pnc_tx_stg_cmb_id comb_id,
    '[' || wm_concat('{"innerConceptName":' || '"' || combMap.concept_name  || '"' || 
    ',"innerConceptId":' || combMap.concept_id || '}') || ']' conceptsArray,
    wm_concat(combMap.concept_name) conceptsName
    from @results_schema.pnc_tx_stage_combination comb
    join @results_schema.pnc_tx_stage_combination_map combMap 
    on comb.pnc_tx_stg_cmb_id = combmap.pnc_tx_stg_cmb_id
    where comb.study_id = @studyId
    group by comb.pnc_tx_stg_cmb_id
) studyCombo;

-------------------------filtering based on filter out conditions -----------------------
IF OBJECT_ID('tempdb..#_pnc_smrypth_fltr', 'U') IS NOT NULL
  DROP TABLE #_pnc_smrypth_fltr;

CREATE TABLE #_pnc_smrypth_fltr
(
    pnc_stdy_smry_id int,
    study_id    int,
    source_id int,
    tx_path_parent_key  int,
    tx_stg_cmb    VARCHAR(255),
    tx_stg_cmb_pth VARCHAR(4000),
    tx_seq          int,
    tx_stg_cnt      int,
    tx_stg_percentage float,
    tx_stg_avg_dr   int,
    tx_stg_avg_gap   int,
    tx_rslt_version int
);

insert into #_pnc_smrypth_fltr 
select pnc_stdy_smry_id, study_id, source_id, tx_path_parent_key, tx_stg_cmb, tx_stg_cmb_pth,
    tx_seq,
    tx_stg_cnt,
    tx_stg_percentage,
    tx_stg_avg_dr,
    tx_stg_avg_gap,
    tx_rslt_version 
    from @results_schema.pnc_study_summary_path
        where 
        study_id = @studyId
        and source_id = @sourceId
        and tx_rslt_version = 2;

----------- delete rows that do not qualify the conditions for fitlering out-----------
delete from #_pnc_smrypth_fltr where pnc_stdy_smry_id not in (
    select pnc_stdy_smry_id from #_pnc_smrypth_fltr qualified
--TODO!!!!!! change this with real condition string
--    where tx_stg_avg_dr >= 50);
--    where tx_stg_avg_gap < 150
@constraintSql
);


--table to hold null parent ids (which have been deleted from #_pnc_smrypth_fltr as not qualified rows) and all their ancestor_id with levels
IF OBJECT_ID('tempdb..#_pnc_smry_ancstr', 'U') IS NOT NULL
  DROP TABLE #_pnc_smry_ancstr;

CREATE TABLE #_pnc_smry_ancstr
(
    pnc_stdy_parent_id    int,
    pnc_ancestor_id    int,
    reallevel int
);

insert into #_pnc_smry_ancstr
select nullParentKey, pnc_stdy_smry_id, realLevel
from (
  select validancestor.nullParentKey, validancestor.ancestorlevel, 
  case 
      when path.pnc_stdy_smry_id is not null then validancestor.ancestorlevel
      when path.pnc_stdy_smry_id is null then 1000000
    end as realLevel,
  validancestor.parentid, path.pnc_stdy_smry_id
  from #_pnc_smrypth_fltr path
  right join
  (select smry.tx_path_parent_key nullParentKey, nullParentAncestors.l ancestorLevel, nullParentAncestors.parent parentId from #_pnc_smrypth_fltr smry
    join
    (SELECT pnc_stdy_smry_id, ancestor AS parent, l
      FROM
      (
        SELECT pnc_stdy_smry_id, tx_path_parent_key, LEVEL-1 l, 
        connect_by_root pnc_stdy_smry_id ancestor
        FROM @results_schema.pnc_study_summary_path
        where 
        study_id = @studyId
        and source_id = @sourceId
        and tx_rslt_version = 2
      	CONNECT BY PRIOR pnc_stdy_smry_id = tx_path_parent_key
      ) t
      WHERE t.ancestor <> t.pnc_stdy_smry_id
      and t.pnc_stdy_smry_id in 
      (select tx_path_parent_key from #_pnc_smrypth_fltr where tx_path_parent_key not in (select PNC_STDY_SMRY_ID from #_pnc_smrypth_fltr))
    ) nullParentAncestors
    on smry.tx_path_parent_key = nullParentAncestors.pnc_stdy_smry_id) validAncestor
  on path.pnc_stdy_smry_id = validAncestor.parentId);

--update null parent key in #_pnc_smrypth_fltr with valid ancestor id which exists in #_pnc_smrypth_fltr or null (null is from level set to 1000000 from table of #_pnc_smry_ancstr)
merge into #_pnc_smrypth_fltr m
using
  (
    select path.pnc_stdy_smry_id, updateParent.pnc_ancestor_id from #_pnc_smrypth_fltr path,
    (select pnc_stdy_parent_id, pnc_ancestor_id
    	from (select pnc_stdy_parent_id, pnc_ancestor_id, reallevel, 
    	row_number() over (partition by pnc_stdy_parent_id order by reallevel) rn
    	from #_pnc_smry_ancstr)
    where rn = 1) updateParent
    where path.tx_path_parent_key = updateParent.pnc_stdy_parent_id
  ) m1
  on
  (
     m.pnc_stdy_smry_id = m1.pnc_stdy_smry_id
  )
  WHEN MATCHED then update set m.tx_path_parent_key = m1.pnc_ancestor_id;

------------------------version 2 of filtered JSON into summary table-----------------
update @results_schema.pnc_study_summary set study_results_filtered = (select JSON from (
select JSON from (
SELECT
   table_row_id,
   DBMS_XMLGEN.CONVERT (
     EXTRACT(
       xmltype('<?xml version="1.0"?><document>' ||
               XMLAGG(
                 XMLTYPE('<V>' || DBMS_XMLGEN.CONVERT(JSON)|| '</V>')
                 order by rnum).getclobval() || '</document>'),
               '/document/V/text()').getclobval(),1) AS JSON
FROM (select allRoots.rnum rnum, 1 table_row_id,
CASE 
    WHEN rnum = 1 THEN '{"comboId": "root","children": [' || substr(JSON_SNIPPET, 2, length(JSON_SNIPPET))
    ELSE JSON_SNIPPET
END
as JSON
from 
(WITH connect_by_query as (
		select  
        individualPathNoParentConcepts.rnum                               as rnum
      ,individualPathNoParentConcepts.combo_id                            as combo_id
      ,individualPathNoParentConcepts.current_path                        as current_path
      ,individualPathNoParentConcepts.path_seq                            as path_seq
      ,individualPathNoParentConcepts.avg_duration                        as avg_duration
	  ,individualPathNoParentConcepts.avg_gap                       	  as avg_gap
      ,individualPathNoParentConcepts.gap_pcnt							  as gap_pcnt
      ,individualPathNoParentConcepts.pt_count                            as pt_count
      ,individualPathNoParentConcepts.pt_percentage                       as pt_percentage
      ,individualPathNoParentConcepts.concept_names                       as concept_names
      ,individualPathNoParentConcepts.combo_concepts                      as combo_concepts
      ,individualPathNoParentConcepts.Lvl                                 as Lvl
    , parentConcepts.conceptsName                                         as parent_concept_names
    , parentConcepts.conceptsArray                                        as parent_combo_concepts
    from 
    (SELECT 
     ROWNUM                               as rnum
    ,tx_stg_cmb                           as combo_id
    ,tx_stg_cmb_pth                       as current_path
    ,tx_seq                               as path_seq
    ,tx_stg_avg_dr                        as avg_duration
    ,tx_stg_avg_gap                       as avg_gap
    ,NVL(ROUND(tx_stg_avg_gap/tx_stg_avg_dr * 100,2),0)   as gap_pcnt
    ,tx_stg_cnt                           as pt_count
    ,tx_stg_percentage                    as pt_percentage
    ,concepts.conceptsName                as concept_names
    ,concepts.conceptsArray               as combo_concepts
    ,LEVEL                                as Lvl
    ,pnc_stdy_smry_id                     as self_id
    ,tx_path_parent_key                   as parent_id
    ,prior tx_stg_cmb                     as parent_comb
  FROM #_pnc_smrypth_fltr smry
  join #_pnc_smry_msql_cmb concepts
  on concepts.pnc_tx_stg_cmb_id = smry.tx_stg_cmb
  START WITH pnc_stdy_smry_id in (select pnc_stdy_smry_id from #_pnc_smrypth_fltr
        where 
--        study_id = 19
--        and source_id = 2
--        and tx_rslt_version = 2
        tx_path_parent_key is null)
  CONNECT BY PRIOR pnc_stdy_smry_id = tx_path_parent_key
  ORDER SIBLINGS BY pnc_stdy_smry_id
  ) individualPathNoParentConcepts
  left join #_pnc_smry_msql_cmb parentConcepts
  on parentConcepts.pnc_tx_stg_cmb_id = individualPathNoParentConcepts.parent_comb
  order by rnum
)
select 
  rnum rnum,
  CASE 
    WHEN Lvl = 1 THEN ',{'
    WHEN Lvl - LAG(Lvl) OVER (order by rnum) = 1 THEN ',"children" : [{' 
    ELSE ',{' 
  END 
  || ' "comboId" : ' || combo_id || ' '
  || ' ,"conceptName" : "' || concept_names || '" '  
  || ' ,"patientCount" : ' || pt_count || ' '
  || ' ,"percentage" : "' || pt_percentage || '" '  
  || ' ,"avgDuration" : ' || avg_duration || ' '
  || ' ,"avgGapDay" : ' || avg_gap || ' '
  || ' ,"gapPercent" : "' || gap_pcnt || '" '
  || ',"concepts" : ' || combo_concepts 
  || CASE WHEN Lvl > 1 THEN    
        ',"parentConcept": { "parentConceptName": "' || parent_concept_names || '", '  
        || '"parentConcepts":' || parent_combo_concepts   || '}'
     ELSE  NULL
     END 
  || CASE WHEN LEAD(Lvl, 1, 1) OVER (order by rnum) - Lvl <= 0 
     THEN '}' || rpad( ' ', 1+ (-2 * (LEAD(Lvl, 1, 1) OVER (order by rnum) - Lvl)), ']}' )
     ELSE NULL 
  END as JSON_SNIPPET
from connect_by_query
order by rnum) allRoots
union all
select rnum as rnum, table_row_id as table_row_id, ']}' as JSON from (
	select distinct 1/0F as rnum, 1 as table_row_id from #_pnc_smrypth_fltr)
)
GROUP BY
   table_row_id))), 
last_update_time = CURRENT_TIMESTAMP 
where study_id = @studyId and source_id = @sourceId;


IF OBJECT_ID('tempdb..#_pnc_smrypth_fltr', 'U') IS NOT NULL
  DROP TABLE #_pnc_smrypth_fltr;
IF OBJECT_ID('tempdb..#_pnc_smry_ancstr', 'U') IS NOT NULL
  DROP TABLE #_pnc_smry_ancstr;
IF OBJECT_ID('tempdb..#_pnc_ptsq_ct', 'U') IS NOT NULL
  DROP TABLE #_pnc_ptsq_ct;
IF OBJECT_ID('tempdb..#_pnc_ptstg_ct', 'U') IS NOT NULL
  DROP TABLE #_pnc_ptstg_ct;
IF OBJECT_ID('tempdb..#_pnc_tmp_cmb_sq_ct', 'U') IS NOT NULL
  DROP TABLE #_pnc_tmp_cmb_sq_ct;
IF OBJECT_ID('tempdb..#_pnc_smry_msql_cmb', 'U') IS NOT NULL
  DROP TABLE #_pnc_smry_msql_cmb;