# SES Production Access Setup Guide

To complete the move to SES Production, follow these steps in the AWS Console to connect your SES notifications to the new blacklist system.

## 1. Create an SNS Topic
1. Go to **Simple Notification Service (SNS)** in the AWS Console.
2. Select **Topics** -> **Create topic**.
3. Type: **Standard**.
4. Name: `ses-notifications`.
5. Create topic.

## 2. Configure SNS Subscription
1. Inside the `ses-notifications` topic, select **Create subscription**.
2. Protocol: **HTTPS**.
3. Endpoint: `https://zgcy1tisjc.execute-api.ap-south-1.amazonaws.com/prod/dbhandler`
4. Create subscription.

> [!NOTE]
> I have updated the Lambda function to automatically detect SNS notifications. You do **not** need to manually configure the JSON payload or map fields in API Gateway. The Lambda will even handle the "Subscription Confirmation" automatically when you add the endpoint.

## 3. Recommended: SNS-to-Lambda Direct Trigger
Instead of HTTPS, a direct Lambda trigger is more reliable:
1. Go to your Lambda function (`ruchiserv-api`).
2. Select **Add trigger** -> **SNS**.
3. Select the `ses-notifications` topic.
4. Update the Lambda to detect if the event is an SNS event. (Currently, the code expects an API Gateway body).

## 4. Configure SES Notifications
1. Go to **Amazon SES**.
2. Select **Verified Identities** -> Pick `ruchiserv.com`.
3. Under the **Notifications** tab, select **Edit**.
4. For **Feedback forwarding**, ensure it's **Enabled**.
5. For **Bounce** and **Complaint**, select the `ses-notifications` SNS topic you created.
6. Save Configuration.

## 5. Verify Setup
1. Use the **SES Send Test Email** feature.
2. From: any verified email.
3. To: `bounce@simulator.amazonses.com`.
4. Check your DynamoDB table `ruchiserv-email-blacklist`. It should now contain the bounced email.
