# Scenario 2: APIs-as-a-Product - Public and Private APIs Strategy

## 1. Overview and Context

This scenario evaluates the current architecture for building and deploying APIs on AWS, encompassing both internal (application-to-application) and public (customer, broker, etc.) usage patterns. The goal is to identify weaknesses in the existing setup and propose a revised architecture that securely and efficiently handles different API exposure levels, specifically addressing the need for private APIs and optimized internal traffic flow.

## 2. Understanding the Current Architecture

Based on the provided diagram and technical details, the current API deployment model exhibits the following characteristics:

*   **Unified Entry Point:** All API traffic, regardless of origin (public internet or internal network), is routed through a single domain (`api.<organization-domain>.com`) served by **Amazon CloudFront**.
*   **Edge Security:** The CloudFront distribution is protected by **AWS Global WAF v2** and **AWS Shield Advanced**.
*   **API Gateway Layer:** Traffic is then directed to multiple **Amazon API Gateway** regional endpoints. These APIs are developed and maintained by different teams.
*   **Authentication/Authorization:** A central **AWS Lambda Authorizer** is invoked by the API Gateways to handle identity and authorization before requests reach backend services.
*   **Backend Services:** The actual business logic resides in either:
    *   **AWS Lambda** functions.
    *   Internal **Application Load Balancers (ALBs)** fronting **AWS ECS Fargate** microservices.
*   **Design Philosophy:** A key point mentioned is that *all APIs are currently public "by design"*, accessible via the single CloudFront endpoint.
*   **(Diagram/Text Discrepancy Noted):** The provided diagram includes an icon labeled "Regional waf" positioned between the Global WAF and the API Gateways. However, the technical details only explicitly mention the *Global* WAF associated with CloudFront. AWS WAF deployment patterns typically involve either Global WAF (on CloudFront) OR Regional WAF (on regional resources like API Gateway/ALB), not usually in direct series for the same CloudFront-originating traffic. We will proceed assuming the primary current defense is the Global WAF as stated in the text, but will address the *need* for regional-level protection (potentially via Regional WAF on API GW or other mechanisms) as part of the weaknesses (Q1) and bypass protection solutions (Q4).

*(Placeholder for a cleaned/annotated current architecture diagram, e.g., `./diagrams/scenario2-current-architecture.png`)*

## 3. Question 1: Weaknesses in the Current Architecture

The current API architecture, while functional, presents several significant weaknesses, particularly concerning security posture, operational efficiency, and alignment with best practices for mixed public/internal API exposure:

1.  **Universal Public Exposure:**
    *   **Issue:** The most critical weakness is that *all* APIs, including those intended solely for internal application integration, are exposed publicly via the single CloudFront distribution (`api.<organization-domain>.com`) and associated regional API Gateway endpoints. This is explicitly mentioned as being "by design".
    *   **Risk:** This unnecessarily increases the attack surface. Internal APIs, which might have different security requirements or assumptions, are subjected to potential external threats, reconnaissance, and abuse attempts. It violates the principle of least exposure.

2.  **Potential for CloudFront/WAF Bypass:**
    *   **Issue:** The regional API Gateway endpoints themselves are publicly accessible (by default when created as REGIONAL type). While traffic *should* come through CloudFront/Global WAF, malicious actors or misconfigured clients could potentially discover and directly hit the `execute-api` URLs of the regional API Gateways.
    *   **Risk:** This bypasses the critical security layers provided by AWS Global WAF and Shield Advanced at the edge (CloudFront), potentially exposing the backend to direct attacks, DDoS, or uninspected traffic. (This is directly addressed in Question 4).

3.  **Ambiguous/Potentially Flawed WAF Strategy:**
    *   **Issue:** There is a discrepancy between the technical details (mentioning only the Global WAF at CloudFront) and the architecture diagram (showing an additional "Regional waf" in the flow).
        *   If there's *no* regional WAF protection directly on the API Gateways, it exacerbates the bypass risk (#2).
        *   If there *is* a Regional WAF *in addition* to the Global WAF (as the diagram might imply, although configured differently than shown), there could be redundant rule processing, increased management overhead, and potential cost inefficiencies if not designed carefully.
    *   **Risk:** Lack of clarity in the security design; potential gaps in protection if only Global WAF exists and bypass occurs; potential inefficiency if both exist without clear role separation.

4.  **Inefficient Internal Traffic Routing:**
    *   **Issue:** Internal clients/applications needing to consume internal APIs currently have to route their traffic out to the public internet, through CloudFront/WAF, and back into AWS to reach the API Gateway.
    *   **Risk:** This introduces unnecessary latency, potential egress data transfer costs, and subjects purely internal traffic to external security checks and potential edge failures, impacting internal system performance and reliability.

5.  **Centralized Lambda Authorizer Bottleneck/Blast Radius:**
    *   **Issue:** While centralizing authorization can have benefits, using a single Lambda Authorizer for *all* API Gateways creates a potential performance bottleneck and a single point of failure.
    *   **Risk:** High load across all APIs could throttle the authorizer. An error or failure within this single Lambda function could impact the availability of *all* APIs simultaneously, increasing the blast radius of any incident related to authorization.

6.  **Management Complexity:**
    *   **Issue:** Managing multiple independent API Gateways developed by different teams without strong governance can lead to inconsistencies in configuration, stage deployment, logging, monitoring, and adherence to standards.
    *   **Risk:** Increased operational burden, potential for configuration drift, and difficulties in maintaining a unified view of the entire API landscape.

## 4. Question 2: Redesign for Private API Exposure

To address the weaknesses identified, particularly the universal public exposure and inefficient internal routing, we propose a revised architecture focused on leveraging VPC endpoints and potentially distinct API Gateway deployments for different exposure levels. The goal is simplicity, efficiency, and minimal disruption compared to the current setup.

**Core Concepts of the Proposed Architecture:**

1.  **Introduce VPC Interface Endpoint for API Gateway (`execute-api`):**
    *   **Mechanism:** Deploy an **Interface VPC Endpoint** for the `execute-api` service within the VPC(s) where internal clients reside.
    *   **Benefit:** This creates a private entry point to access regional API Gateway APIs *directly from within the VPC* using private IP addresses, completely bypassing the public internet, CloudFront, and the Global WAF for internal traffic. This significantly reduces latency and potential egress costs for internal calls.

## 5. Question 3: CloudFront Path-Based Routing Configuration

*(Content to be added)*

## 6. Question 4: Protecting Regional APIGW Endpoints from Bypass

*(Content to be added)*

## 7. Proposed Architecture Diagram

*(Placeholder for the proposed architecture diagram, e.g., `./diagrams/scenario2-proposed-architecture.png`)*

## 8. Additional Considerations (Security, Governance, Cost)

*(Content to be added)*

## 9. References

*(Content to be added)*

---
*This concludes the detailed analysis and proposed solution for Scenario 2.*