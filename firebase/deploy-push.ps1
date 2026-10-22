# Deploy sendAdminPush Cloud Function (required for admin push notifications).
Set-Location $PSScriptRoot

Write-Host "Installing function dependencies..."
npm install --prefix functions

Write-Host "Deploying sendAdminPush to Firebase project mprs-rms..."
npx firebase-tools login
npx firebase-tools deploy --only functions:sendAdminPush

Write-Host "Done. Test URL:"
Write-Host "https://us-central1-mprs-rms.cloudfunctions.net/sendAdminPush"
