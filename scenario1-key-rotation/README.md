# Scenario 1: AWS KMS Key Rotation Strategy

## 1. Overview and Context

This scenario addresses a simulated regulatory requirement mandating periodic key rotation for all applicable AWS Key Management Service (KMS) Customer Master Keys (CMKs). The current environment utilizes a centralized KMS setup within a dedicated security account and employs the Bring Your Own Key (BYOK) model, importing key material generated from an on-premise Hardware Security Module (HSM).

The primary goal is to define and implement a robust, secure, and minimally disruptive key rotation strategy that complies with this new requirement across different environments and services.

## 2. Relevant Current Architecture

The existing encryption implementation, illustrated in the provided assessment details, relies on the following key components and principles:

*   **Centralized KMS:** Keys are managed in AWS KMS within a dedicated AWS security account, isolating key management operations.
*   **BYOK Model:** Key material is generated externally on an on-premise HSM and securely imported into AWS KMS. This implies `Origin: EXTERNAL` for the KMS keys.
*   **Segregation:** Encryption is segregated by environment (e.g., Dev, Prod) and by service. Unique keys (or key aliases pointing to potentially unique keys) are used per service (identified in diagrams: S3, RDS, DynamoDB) within each environment.
*   **Key Aliases:** KMS key aliases (e.g., `alias/service-environment`) are used to reference keys, abstracting applications from specific key IDs. This is crucial for simplifying rotation.
*   **Least Privilege:** Key policies are implemented following the principle of least privilege, granting only necessary permissions to users and services.

*(Placeholder for a simplified diagram if needed later, e.g., `./diagrams/current_architecture_overview.png`)*

## 3. Question 1: Key Rotation Challenges and Impacts

Implementing mandatory rotation for existing BYOK KMS keys presents several challenges and potential impacts across technical, operational, and security dimensions:

### 3.1. Service-Specific Technical Challenges

AWS services interact with KMS keys differently, leading to varied rotation impacts:

*   **Amazon S3:**
    *   **Challenge:** Automatic KMS key rotation (via AWS) *does not* apply to existing S3 objects. When a key is rotated (new key material imported or alias updated), only *new* objects written to the bucket will be encrypted with the new key version. Existing objects remain encrypted with the previous key version.
    *   **Impact:** To achieve full compliance for data-at-rest over time, existing objects may require manual re-encryption (e.g., using S3 Batch Operations with a Lambda function or a COPY operation in place). This can be time-consuming and potentially costly for large buckets.
*   **Amazon RDS:**
    *   **Challenge:** Changing the KMS key associated with an encrypted RDS instance typically involves creating a new snapshot, copying the snapshot while specifying the *new* KMS key, and then restoring the instance from the encrypted copy or modifying the instance directly (depending on DB engine and specifics).
    *   **Impact:** This process often requires downtime for the database instance during the snapshot copy and restore/modification phase. The duration depends on database size and underlying operations. Careful planning and execution within maintenance windows are critical. Existing automated snapshots will also use the key version active at the time of their creation.
*   **Amazon DynamoDB:**
    *   **Challenge:** Tables encrypted with KMS (SSE-KMS) using a Customer Managed Key (CMK) handle key reference typically via alias. When the alias points to a new key/version, *newly written data* will use that new key. AWS manages the background encryption process. Similar to S3, DynamoDB *does not automatically re-encrypt all existing data* immediately upon alias change or key material rotation. Re-encryption happens over time as data is naturally rewritten or potentially through a full table export/import or backup/restore cycle if immediate compliance is mandated for all data.
    *   **Impact:** Potential performance implications during periods of heavy writes or explicit re-encryption activities. The primary impact is ensuring compliance timelines align with how DynamoDB handles key changes for existing data.

*(Placeholder for a diagram illustrating these differential impacts, e.g., `./diagrams/service_specific_challenges.png`)*

### 3.2. Operational Challenges

*   **Coordination:** Managing rotation across multiple environments (Dev, Int, Prod) and various service teams requires significant coordination and planning.
*   **Alias Management:** Strict discipline is needed to ensure applications *consistently* use key aliases instead of hardcoded Key IDs. Any direct Key ID usage will break upon rotation.
*   **BYOK Process Complexity:** The process of generating, securely transporting, and importing new key material from the on-premise HSM adds operational overhead compared to AWS-generated keys with automatic rotation.
*   **Testing and Validation:** Thorough testing is required in lower environments before applying changes in production to ensure applications function correctly with the rotated keys.
*   **Rollback Complexity:** Rolling back a key rotation, especially after new data has been written with the new key, can be complex and may require restoring from backups.

### 3.3. Application and Security Impacts

*   **Potential Downtime:** As noted for RDS, downtime might be required, impacting application availability.
*   **Transitional Risk:** During the rotation window (importing new key, updating alias, validating), there's a brief period where operational errors could potentially impact encryption availability or correctness if not handled carefully.
*   **Auditing and Compliance:** Ensuring the entire process is auditable and provides clear evidence of compliance (which key was active when, verification of rotation) is crucial. Key creation/import timestamps in CloudTrail are vital.
*   **Policy Updates:** Key policies might need review or updates if rotation affects how keys are administered or used.

### 3.4. Cost Implications

*   **API Costs:** KMS API calls (encryption, decryption, import) might increase, especially if manual re-encryption activities (like S3 Batch) are performed at scale.
*   **Operational Effort:** The human effort involved in planning, executing, and validating the rotation represents a cost.
*   **Compute/Storage Costs:** Re-encryption tasks (S3 Batch, RDS snapshot copy/restore) can incur temporary compute and storage costs.

## 4. Question 2: Key Rotation Process (High-Level)

The key rotation process for BYOK keys requires careful planning and execution. It can be broken down into the following high-level phases:

### 4.1. Phase 1: Preparation and Planning

*   **Inventory and Analysis:**
    *   Identify all KMS keys currently in use (`Origin: EXTERNAL`) across all environments and services.
    *   Map each key alias to the specific resources it encrypts (S3 buckets, RDS instances, DynamoDB tables, etc.). Automated scripting (e.g., using AWS SDK/CLI) is highly recommended for accuracy at scale.
    *   Analyze potential impacts based on service type (as detailed in Section 3).
    *   Define the target rotation frequency based on regulatory requirements and internal security policies.
*   **Risk Assessment:** Evaluate risks associated with the rotation process for critical applications and data.
*   **Detailed Plan:** Create a detailed execution plan, including:
    *   Sequencing (e.g., which environments/services rotate first - typically non-production first).
    *   Maintenance windows for services requiring downtime (like RDS).
    *   Communication plan for stakeholders and application teams.
    *   Rollback procedures in case of critical failure.
*   **Pre-computation/Checks:** Ensure the on-premise HSM is ready, personnel are trained, and necessary IAM permissions for import are in place.

### 4.2. Phase 2: Execution

*   **Generate New Key Material:** Create new cryptographic key material on the designated on-premise HSM according to its procedures.
*   **Secure Import:** Securely import the new key material into the *existing* target KMS CMK in the security account. (Refer to Section 6 for details on securing this transport).
    *   **Important:** We are *rotating the material* of an existing CMK, not creating a brand new CMK for each rotation, unless policy dictates otherwise (which adds complexity). Importing new material automatically creates a new *backing key version* within the same CMK ARN/ID.
*   **Update Key Alias:** **Crucially**, update the relevant KMS key alias (e.g., `alias/service-environment`) to point to the CMK *after* the new key material has been successfully imported. This redirects all *new* encryption/decryption operations using that alias to utilize the newly imported key material. The AWS CLI `update-alias` or SDK equivalent is used here.
*   **Trigger Re-encryption (If Necessary):** For services like S3 where existing data isn't automatically re-encrypted, initiate planned re-encryption processes (e.g., S3 Batch Operations) if required by compliance timelines.

### 4.3. Phase 3: Validation and Monitoring

*   **Functional Testing:** Application teams perform functional tests to verify applications relying on the rotated keys operate correctly.
*   **Encryption Verification:**
    *   Check new objects/data created in S3, RDS, DynamoDB are using the new key version (can be verified via API calls like `HeadObject` in S3, checking KMS Key ID references, or through CloudTrail event analysis).
    *   Monitor CloudTrail logs for any KMS encryption/decryption errors related to the rotated keys or aliases.
*   **Performance Monitoring:** Monitor application and database performance metrics for any unexpected degradation.
*   **Compliance Monitoring:** Verify that the monitoring setup (detailed in Section 5) correctly reflects the new key status and rotation timestamp.

### 4.4. Phase 4: Post-Rotation Cleanup

*   **Old Key Material:** The previous key material imported into KMS remains available for decrypting older data until it expires (if an expiration date was set during import) or is manually deleted according to retention policies. *Note: Deleting key material makes data encrypted solely with it unrecoverable.* A safer approach is often to let unused imported material expire naturally or remain indefinitely if storage permits and regulations allow, relying on the CMK *state* (e.g., `Disabled`, `PendingDeletion`) for control if needed.
*   **Documentation:** Update operational runbooks, CMDBs, or documentation to reflect the completed rotation cycle and the timestamp.
*   **Lessons Learned:** Conduct a brief retrospective to identify improvements for the next rotation cycle.

*(Placeholder for a process flow diagram, e.g., `./diagrams/key_rotation_flow.png`)*

### 4.5. Automation and DevSecOps Considerations

*   **Automate Where Possible:** Script inventory checks, alias updates, and validation steps to reduce manual effort and errors.
*   **Security Checkpoints:** Integrate security validation steps (e.g., checking key policy correctness post-rotation) into the process.
*   **Infrastructure as Code (IaC):** While the key material import itself is a manual/scripted operation, surrounding infrastructure (like monitoring rules detailed later) should be managed via IaC (Terraform/CloudFormation).

## 5. Question 3: Monitoring Non-Compliant Resources (AWS Managed Services)

To continuously monitor resources encrypted with BYOK keys and ensure their key material is rotated according to the defined policy (e.g., annually), we can leverage several integrated AWS managed services. The core challenge lies in tracking the age of the *imported key material* for keys with `Origin: EXTERNAL`, as standard AWS Config rules primarily check if automatic rotation is enabled (not applicable here).

### 5.1. Proposed Monitoring Architecture

The recommended approach involves using **AWS Config** with a **custom rule** backed by an **AWS Lambda function**. This setup allows for tailored compliance checks specific to the BYOK key rotation requirement.

**Key Services Involved:**

1.  **AWS Config:**
    *   **Purpose:** Resource inventory, configuration history, and compliance checking framework.
    *   **Role:** Deploys a *custom rule* that periodically evaluates the compliance status of BYOK KMS keys.
2.  **AWS Lambda:**
    *   **Purpose:** Provides the custom evaluation logic for the AWS Config rule.
    *   **Role:** The Lambda function code will:
        *   Receive the KMS key ARN (or identifier) as input from AWS Config.
        *   Verify the key `Origin` is `EXTERNAL`.
        *   Query **AWS CloudTrail** logs (using API calls like `lookup_events`) to find the timestamp of the *most recent successful* `ImportKeyMaterial` event for that specific key ARN.
        *   Calculate the age of the imported key material based on the current date and the event timestamp.
        *   Compare this age against the mandated rotation period (e.g., 365 days, configurable via Lambda environment variables or rule parameters).
        *   Return the compliance status (`COMPLIANT` or `NON_COMPLIANT`) and annotation back to AWS Config.
3.  **AWS CloudTrail:**
    *   **Purpose:** Logs API activity within the AWS account.
    *   **Role:** Provides the essential audit trail containing the `ImportKeyMaterial` events and their timestamps, which the Lambda function queries to determine the last rotation date. CloudTrail must be enabled and configured to log KMS events.
4.  **Amazon EventBridge:**
    *   **Purpose:** Central event bus service.
    *   **Role:** Captures compliance change events published by AWS Config (e.g., when a key transitions to `NON_COMPLIANT`). These events can trigger downstream actions like:
        *   Sending notifications via **Amazon SNS** (Simple Notification Service) to security/ops teams.
        *   Triggering automated remediation workflows (if applicable and safe).
5.  **AWS Security Hub:**
    *   **Purpose:** Centralized view of security and compliance findings.
    *   **Role:** Integrates with AWS Config to ingest compliance findings. This provides a unified dashboard to view non-compliant keys alongside other security alerts across the AWS environment.
6.  **Amazon CloudWatch:**
    *   **Purpose:** Monitoring and observability service.
    *   **Role:**
        *   Collects logs from the Lambda function for debugging and monitoring its execution.
        *   Can be used to create dashboards visualizing the overall compliance status (e.g., number of compliant vs. non-compliant keys over time) based on metrics derived from Config/EventBridge events.
        *   Can trigger CloudWatch Alarms based on non-compliance events or Lambda errors.

*(Placeholder for an architecture diagram, e.g., `./diagrams/monitoring_architecture.png`)*

### 5.2.

## 6. Question 4: Securing Key Material Transportation (HSM to KMS)

*(Content to be added later)*

## 7. Additional Considerations and Next Steps

*(Content to be added later)*

## 8. References

*(Content to be added later)*