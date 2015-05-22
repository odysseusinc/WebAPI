/*
 * Copyright 2015 Observational Health Data Sciences and Informatics [OHDSI.org].
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package org.ohdsi.webapi.cohortdefinition;

import java.io.Serializable;
import java.util.Date;
import javax.persistence.Column;
import javax.persistence.EmbeddedId;
import javax.persistence.Entity;
import javax.persistence.Id;
import javax.persistence.JoinColumn;
import javax.persistence.ManyToOne;
import javax.persistence.OneToOne;
import javax.persistence.PrimaryKeyJoinColumn;
import javax.persistence.Table;

/**
 *
 * @author Chris Knoll <cknoll@ohdsi.org>
 */
@Entity(name = "CohortGenerationInfo")
@Table(name="cohort_generation_info")
public class CohortGenerationInfo implements Serializable {
  private static final long serialVersionUID = 1L;

  private  CohortGenerationInfo()
  {    
  }
  
  public CohortGenerationInfo(CohortDefinition cohortDefinition)
  {
    this.cohortDefinition = cohortDefinition;
  }
  
  @Id
  @Column(name="source_id")
  private Integer sourceId;
  
  @ManyToOne
  @Id
  @JoinColumn(name="id", referencedColumnName="id")
  private CohortDefinition cohortDefinition;

  @Column(name="start_time")
  private Date startTime;  
  
  @Column(name="execution_duration")
  private Integer executionDuration;    
  
  @Column(name="status")
  private GenerationStatus status;    
  
  @Column(name="is_valid")
  private boolean isValid;


  public Integer getSourceId()
  {
    return this.sourceId;
  }

  public void setSourceId(Integer sourceId) {
    this.sourceId = sourceId;
  }
  
  public Date getStartTime() {
    return startTime;
  }

  public CohortGenerationInfo setStartTime(Date startTime) {
    this.startTime = startTime;
    return this;
  }

  public Integer getExecutionDuration() {
    return executionDuration;
  }

  public CohortGenerationInfo setExecutionDuration(Integer executionDuration) {
    this.executionDuration = executionDuration;
    return this;
  }

  public GenerationStatus getStatus() {
    return status;
  }

  public CohortGenerationInfo setStatus(GenerationStatus status) {
    this.status = status;
    return this;
  }

  public boolean isIsValid() {
    return isValid;
  }

  public CohortGenerationInfo setIsValid(boolean isValid) {
    this.isValid = isValid;
    return this;
  }
}
