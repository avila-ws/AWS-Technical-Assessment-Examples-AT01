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