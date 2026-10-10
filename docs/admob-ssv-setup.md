# AdMob Server-Side Verification (SSV) Setup

## Overview
The app uses Google AdMob rewarded ads. Server-Side Verification (SSV) ensures that reward claims are legitimate by having Google verify the reward on your backend (Cloudflare Worker) before awarding credits to the user.

## How It Works

1. **User watches rewarded ad** → Google Mobile Ads SDK displays the ad in the app
2. **Ad completes** → Google awards the reward and calls your SSV callback URL
3. **Callback verification** → Google sends `GET /ssv?custom_data={userId}&transaction_id=...&signature=...&key_id=...` to your worker
4. **Worker validates** → Cloudflare Worker verifies the signature using Google's public keys
5. **Credits awarded** → If valid, worker adds credits to the user's account

## Configuration Steps

### Step 1: Get Your App ID and Ad Unit ID

Your current configuration in [.env](.env):
```
ADMOB_APP_ID_ANDROID=ca-app-pub-7026654571602193~1170837743
ADMOB_REWARDED_AD_UNIT_ANDROID=ca-app-pub-7026654571602193/7161531023
ADMOB_APP_ID_IOS=ca-app-pub-0000000000000000~0000000000
ADMOB_REWARDED_AD_UNIT_IOS=ca-app-pub-7026654571602193/1712485313
```

**TODO**: Replace the placeholder iOS values with real app IDs from your Google AdMob account.

### Step 2: Configure SSV Callback in AdMob Console

1. Go to [Google AdMob Console](https://admob.google.com)
2. Select your app (roast-n-rizz)
3. Navigate to **App settings** → **App monetization**
4. Look for "Rewarded ads" or "Monetization" settings
5. Set the **Server-Side Verification callback URL** to:
   ```
   https://roast-rizz-api.rusobrg.workers.dev/ssv
   ```

### Step 3: Configure Custom Data (User ID)

When your app watches a rewarded ad, it must pass the `userId` as custom data:

**Current implementation** in [lib/controllers/home_controller.dart](lib/controllers/home_controller.dart):
```dart
await RewardedAd.load(
  adUnitId: AdConfig.rewardedAdUnitId,
  request: AdRequest(
    keywords: ['funny', 'ai'],
  ),
  rewardedAdLoadCallback: RewardedAdLoadCallback(
    onAdLoaded: (ad) {
      // ... show ad
      RewardedAd.create(ad).show(
        onUserEarnedReward: (ad, reward) {
          credits += _rewardedCredits;
        },
      );
    },
  ),
);
```

**TODO**: Add `customData: userId` to the AdRequest if supported by the Google Mobile Ads SDK version.

### Step 4: Verify Worker Configuration

The worker at [workers/src/index.js](workers/src/index.js) already has SSV implemented:
- ✅ Fetches Google's public verifier keys
- ✅ Verifies the RSA-SHA256 signature
- ✅ Prevents replay attacks with `transaction_id` tracking
- ✅ Awards credits only for valid signatures

**Secrets already configured in Cloudflare**:
- `AZURE_ENDPOINT` (Azure AI endpoint)
- `AZURE_DEPLOYMENT` (Azure deployment name)
- `AZURE_API_KEY` (Azure API key)
- `KV_CREDITS` (Cloudflare KV namespace for credit tracking)

### Step 5: Test SSV Flow

#### Option A: Manual Testing (via integration tests)
```bash
# Start the Cloudflare worker locally
cd workers
wrangler dev

# In another terminal, run the integration tests
cd ..
flutter test test/worker_integration_test.dart
```

#### Option B: Real Device Testing
1. Build and deploy the app to a real Android/iOS device
2. Ensure AdMob test ads are enabled in your app config
3. Watch a rewarded ad
4. Check Cloudflare Worker logs to verify SSV callback was received
5. Verify credits were awarded in the app

#### Option C: Monitor via Cloudflare Dashboard
1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com)
2. Select your Workers project
3. View **Real-Time Logs** to see incoming SSV requests
4. Each successful reward should log:
   ```
   GET /ssv?custom_data={userId}&transaction_id=...&key_id=...&signature=...
   ```

## AdMob Rewarded Ad Implementation Details

The app loads rewarded ads using Google Mobile Ads SDK:

**File**: [lib/controllers/home_controller.dart](lib/controllers/home_controller.dart)
```dart
Future<void> watchRewardedAd({required Function(String) onError}) async {
  if (isRewardLoading) return;
  isRewardLoading = true;

  try {
    var rewardEarned = false;
    await RewardedAd.load(
      adUnitId: AdConfig.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          // Show the ad
          ad.show(onUserEarnedReward: (ad, reward) {
            rewardEarned = true;
            credits += _rewardedCredits; // Add 3 credits
          });
        },
        onAdFailedToLoad: (error) {
          isRewardLoading = false;
          onError('ad_load_failed');
        },
      ),
    );
  } catch (e) {
    isRewardLoading = false;
    onError('reward_error');
  }
}
```

## Troubleshooting

### SSV Callback Not Received
- ✅ Check that the callback URL is correctly set in AdMob Console
- ✅ Verify worker is deployed to production: `https://roast-rizz-api.rusobrg.workers.dev`
- ✅ Check Cloudflare logs for incoming requests to `/ssv`

### Signature Verification Failed
- ✅ Worker logs will show "Invalid signature"
- ✅ This could indicate tampering or incorrect custom_data
- ✅ Verify that the userId format matches: 20-128 alphanumeric characters

### Credits Not Awarded
- ✅ Check that KV namespace is correctly bound in `wrangler.toml`
- ✅ Verify that the transaction_id is unique (replay protection)
- ✅ Check KV store size and eviction policies

### Transaction Already Processed
- ✅ The worker prevents duplicate rewards by tracking `tx_{transactionId}`
- ✅ If Google retries a callback, the second attempt will be ignored (200 OK returned)
- ✅ Transactions are cached for 30 days

## Security Considerations

1. **Signature Verification**: Only RSA-SHA256 verified signatures are accepted
2. **Replay Protection**: Each `transaction_id` is tracked and can only be rewarded once
3. **User ID Validation**: Must match pattern `^[A-Za-z0-9_-]{20,128}$` (20-128 chars)
4. **Key Rotation**: Public keys are fetched fresh and cached for 1 hour
5. **CORS Protection**: Responses include CORS headers but no cross-origin body exposure

## Resources

- [Google AdMob SSV Documentation](https://support.google.com/admob/answer/11701563)
- [Google Mobile Ads SDK for Flutter](https://pub.dev/packages/google_mobile_ads)
- [Cloudflare Workers Documentation](https://developers.cloudflare.com/workers/)
- [Web Crypto API (used for signature verification)](https://developer.mozilla.org/en-US/docs/Web/API/Web_Crypto_API)
