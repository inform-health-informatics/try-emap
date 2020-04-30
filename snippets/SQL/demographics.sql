-- Demographics query
-- Created 2020-04-30

SELECT DISTINCT ON (
  m.mrn)
  m.mrn,
  fname.value_as_string AS first_name,
  mname.value_as_string AS middle_name,
  lname.value_as_string AS last_name,
  postcode.value_as_string AS home_postcode,
  nhs.value_as_string AS nhs_number,
  dob.value_as_datetime AS birthdate,
  sex.short_name AS sex,
  death_date.value_as_datetime AS death_date,
  death_indicator.short_name AS death_indicator
FROM ((((((((((((((((((star_validation.patient_fact pf
  LEFT JOIN star_validation.patient_fact naming
    ON (((naming.encounter = pf.encounter)
    AND (naming.fact_type = (SELECT
        attribute.attribute_id
      FROM star_validation.attribute
      WHERE ((attribute.short_name) :: TEXT = 'NAMING' :: TEXT))
    )
    AND (naming.valid_until IS NULL)
    AND (naming.stored_until IS NULL))))
  LEFT JOIN star_validation.patient_property fname
    ON (((fname.fact = naming.patient_fact_id)
    AND (fname.property_type = (SELECT
        attribute.attribute_id
      FROM star_validation.attribute
      WHERE ((attribute.short_name) :: TEXT = 'F_NAME' :: TEXT))
    )
    AND (fname.valid_until IS NULL)
    AND (fname.stored_until IS NULL))))
  LEFT JOIN star_validation.patient_property mname
    ON (((mname.fact = naming.patient_fact_id)
    AND (mname.property_type = (SELECT
        attribute.attribute_id
      FROM star_validation.attribute
      WHERE ((attribute.short_name) :: TEXT = 'M_NAME' :: TEXT))
    )
    AND (mname.valid_until IS NULL)
    AND (mname.stored_until IS NULL))))
  LEFT JOIN star_validation.patient_property lname
    ON (((lname.fact = naming.patient_fact_id)
    AND (lname.property_type = (SELECT
        attribute.attribute_id
      FROM star_validation.attribute
      WHERE ((attribute.short_name) :: TEXT = 'L_NAME' :: TEXT))
    )
    AND (lname.valid_until IS NULL)
    AND (lname.stored_until IS NULL))))
  LEFT JOIN star_validation.patient_property postcode
    ON (((postcode.fact = pf.patient_fact_id)
    AND (postcode.property_type = (SELECT
        attribute.attribute_id
      FROM star_validation.attribute
      WHERE ((attribute.short_name) :: TEXT = 'POST_CODE' :: TEXT))
    )
    AND (postcode.valid_until IS NULL)
    AND (postcode.stored_until IS NULL))))
  LEFT JOIN star_validation.patient_property nhs
    ON (((nhs.fact = pf.patient_fact_id)
    AND (nhs.property_type = (SELECT
        attribute.attribute_id
      FROM star_validation.attribute
      WHERE ((attribute.short_name) :: TEXT = 'NHS_NUMBER' :: TEXT))
    )
    AND (nhs.valid_until IS NULL)
    AND (nhs.stored_until IS NULL))))
  LEFT JOIN star_validation.patient_property dob
    ON (((dob.fact = pf.patient_fact_id)
    AND (dob.property_type = (SELECT
        attribute.attribute_id
      FROM star_validation.attribute
      WHERE ((attribute.short_name) :: TEXT = 'DOB' :: TEXT))
    )
    AND (dob.valid_until IS NULL)
    AND (dob.stored_until IS NULL))))
  LEFT JOIN star_validation.patient_property sexp
    ON (((sexp.fact = pf.patient_fact_id)
    AND (sexp.property_type = (SELECT
        attribute.attribute_id
      FROM star_validation.attribute
      WHERE ((attribute.short_name) :: TEXT = 'SEX' :: TEXT))
    )
    AND (sexp.valid_until IS NULL)
    AND (sexp.stored_until IS NULL))))
  LEFT JOIN star_validation.attribute sex
    ON ((sex.attribute_id = sexp.value_as_attribute)))
  LEFT JOIN star_validation.patient_fact death_fact
    ON (((death_fact.encounter = pf.encounter)
    AND (death_fact.fact_type = (SELECT
        attribute.attribute_id
      FROM star_validation.attribute
      WHERE ((attribute.short_name) :: TEXT = 'DEATH_FACT' :: TEXT))
    )
    AND (death_fact.valid_until IS NULL)
    AND (death_fact.stored_until IS NULL))))
  LEFT JOIN star_validation.patient_property death_date
    ON (((death_date.fact = death_fact.patient_fact_id)
    AND (death_date.property_type = (SELECT
        attribute.attribute_id
      FROM star_validation.attribute
      WHERE ((attribute.short_name) :: TEXT = 'DEATH_TIME' :: TEXT))
    )
    AND (death_date.valid_until IS NULL)
    AND (death_date.stored_until IS NULL))))
  LEFT JOIN star_validation.patient_property death_ind
    ON (((death_ind.fact = death_fact.patient_fact_id)
    AND (death_ind.property_type = (SELECT
        attribute.attribute_id
      FROM star_validation.attribute
      WHERE ((attribute.short_name) :: TEXT = 'DEATH_INDICATOR' :: TEXT))
    )
    AND (death_ind.valid_until IS NULL)
    AND (death_ind.stored_until IS NULL))))
  LEFT JOIN star_validation.attribute death_indicator
    ON ((death_indicator.attribute_id = death_ind.value_as_attribute)))
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
WHERE ((pf.fact_type = (SELECT
    attribute.attribute_id
  FROM star_validation.attribute
  WHERE ((attribute.short_name) :: TEXT = 'GENERAL_DEMO' :: TEXT))
)
AND (pf.valid_until IS NULL)
AND (pf.stored_until IS NULL))
ORDER BY m.mrn, pm.valid_from, fname.value_as_string;


