## UUPDump Script on Github Actions
The Steps Below will Guide You to use Github Workflow to Build and Download UUPDump ISOs at ease!

## Step 1: Fork the Repository

1. **Fork the Repository**:  
   In the top-right corner of the page, click the **Fork** button. This creates a copy of the repository under your GitHub account.

## Step 2: Get & Upload Your UUPDump Zips

1. **Get Your UUPDump**:  
   - https://uupdump.net/
   - You will need to Make yourself a zip through UUPDump first.

2. **Upload Your Zips**:
   - https://filebin.net/
   - Click on the **Add file** button and select **Upload files**.

## Step 3: Enter URL and Run the Action

1. **Navigate to the Actions Tab**:
   - Go to the **Actions** tab in your forked repository.  
   - This tab lists all workflows in the repository. Find the workflow designed to process your UUPDumps.

2. **Run the Action**:
   - In the Actions tab, locate the workflow named **"Builds"**.
   - Click on the workflow and press the **Run workflow** button.
   - Enter the code you got from filebin to the zip you uploaded in Step 2.
     - You should give the code given by the site. The code should look something like:  
       `0uv3y9tjqm0hjb51`
   - Click **Run workflow** to trigger the GitHub Action.

## Step 4: View Your Windows ISO being created from the Action's Output

1. **Wait for the Action to Complete**:
   - The workflow will begin processing. This includes downloading your zips, extracting files inside then create your ISO.
   - Wait for the action to finish. You can monitor the progress from the GitHub Actions interface.

2. **Check the Output**:
   - Once the action completes, view the **logs** from the workflow run.
   - You’ll see the URL to download your ISO printed at the bottom in step "Upload File & Get Links".

## Credits
[**UUPDump**](https://uupdump.net) For making download updated windows builds easier

[**GoFile**](https://gofile.io) and [**Filebin**](https://filebin.net) for file host used in this repository
