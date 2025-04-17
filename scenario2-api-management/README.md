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


## 4. Question 2: Redesign for Private API Exposure

*(Content to be added)*

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