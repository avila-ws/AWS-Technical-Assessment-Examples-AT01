# Scenario 1: AWS KMS Key Rotation Strategy

## 1. Overview and Context

This scenario addresses a simulated regulatory requirement mandating periodic key rotation for all applicable AWS Key Management Service (KMS) Customer Master Keys (CMKs). The current environment utilizes a centralized KMS setup within a dedicated security account and employs the Bring Your Own Key (BYOK) model, importing key material generated from an on-premise Hardware Security Module (HSM).

The primary goal is to define and implement a robust, secure, and minimally disruptive key rotation strategy that complies with this new requirement across different environments and services.
