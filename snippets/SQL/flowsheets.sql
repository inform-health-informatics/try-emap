-- Flowsheets query
-- Created 2020-04-30

SELECT
  m.mrn,
  en.encounter AS csn,
  pp_datetime.value_as_datetime AS flowsheet_datetime,
  pp_type.value_as_string AS flowsheet_type,
  c.concept_name AS mapped_name,
  pp_result_str.value_as_string AS result_text,
  pp_result_num.value_as_real AS result_as_real
FROM (((((((((((star_validation.patient_fact pf
  LEFT JOIN star_validation.patient_property pp_type
    ON (((pp_type.fact = pf.patient_fact_id)
    AND (pp_type.property_type = (SELECT
        attribute.attribute_id
      FROM star_validation.attribute
      WHERE ((attribute.short_name) :: TEXT = 'VIT_OBS_ID' :: TEXT))
    )
    AND (pp_type.stored_until IS NULL)
    AND (pp_type.valid_until IS NULL))))
  LEFT JOIN star_validation.patient_property pp_result_str
    ON (((pp_result_str.fact = pf.patient_fact_id)
    AND (pp_result_str.property_type = (SELECT
        attribute.attribute_id
      FROM star_validation.attribute
      WHERE ((attribute.short_name) :: TEXT = 'VIT_STR_VALUE' :: TEXT))
    )
    AND (pp_result_str.valid_until IS NULL)
    AND (pp_result_str.stored_until IS NULL))))
  LEFT JOIN star_validation.patient_property pp_result_num
    ON (((pp_result_num.fact = pf.patient_fact_id)
    AND (pp_result_num.property_type = (SELECT
        attribute.attribute_id
      FROM star_validation.attribute
      WHERE ((attribute.short_name) :: TEXT = 'VIT_NUM_VALUE' :: TEXT))
    )
    AND (pp_result_num.valid_until IS NULL)
    AND (pp_result_num.stored_until IS NULL))))
  LEFT JOIN star_validation.patient_property pp_datetime
    ON (((pf.patient_fact_id = pp_datetime.fact)
    AND (pp_datetime.property_type = (SELECT
        attribute.attribute_id
      FROM star_validation.attribute
      WHERE ((attribute.short_name) :: TEXT = 'VIT_OBS_TIME' :: TEXT))
    )
    AND (pp_datetime.valid_until IS NULL)
    AND (pp_datetime.stored_until IS NULL))))
  JOIN star_validation.encounter en
    ON ((pf.encounter = en.encounter_id)))
  LEFT JOIN star_validation.mrn_encounter me
    ON (((en.encounter_id = me.encounter)
    AND (me.stored_until IS NULL)
    AND (me.valid_until IS NULL))))
  LEFT JOIN star_validation.person_mrn pm
    ON (((pm.mrn = me.mrn)
    AND (pm.stored_until IS NULL)
    AND (pm.valid_until IS NULL))))
  LEFT JOIN star_validation.person_mrn pm1
    ON (((pm1.person = pm.person)
    AND pm1.live
    AND (pm1.stored_until IS NULL)
    AND (pm1.valid_until IS NULL))))
  LEFT JOIN star_validation.mrn m
    ON ((pm1.mrn = m.mrn_id)))
  LEFT JOIN ops_validation.etl_labs_metadata elm
    ON ((pp_type.value_as_string = (elm.test_code) :: TEXT)))
  LEFT JOIN ops.concept c
    ON (((elm.omop_code) :: INTEGER = c.concept_id)))
WHERE ((pf.fact_type = (SELECT
    attribute.attribute_id
  FROM star_validation.attribute
  WHERE ((attribute.short_name) :: TEXT = 'VIT_SIGN' :: TEXT))
)
AND (pf.stored_until IS NULL)
AND (pf.valid_until IS NULL));

