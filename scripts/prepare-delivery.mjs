import { execSync } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';

const zipName = "mort-antigravity-fullstack-revenuecat-ai.zip";
console.log(`Preparing delivery: ${zipName}`);

if (fs.existsSync(zipName)) {
  fs.unlinkSync(zipName);
}

const psScript = `
$source = Get-Item .
$dest = "$($source.FullName)\\${zipName}"
$exclude = @("node_modules", ".dart_tool", "build", ".git", ".idea", "${zipName}", "ios/Pods", ".vscode")

Get-ChildItem -Path $source.FullName -Recurse -Exclude $exclude | 
  Where-Object { 
    $path = $_.FullName
    $keep = $true
    foreach ($ex in $exclude) {
      if ($path -match "\\\\$ex\\\\") { $keep = $false; break }
      if ($path -match "/$ex/") { $keep = $false; break }
    }
    $keep
  } | Compress-Archive -DestinationPath $dest -Force
`;

const psScriptPath = path.join(process.cwd(), 'temp_zip.ps1');

try {
  fs.writeFileSync(psScriptPath, psScript);
  console.log("Compressing files. This may take a moment...");
  execSync(`powershell -ExecutionPolicy Bypass -File temp_zip.ps1`, { stdio: 'inherit' });
  console.log(`Successfully created ${zipName}`);
} catch (error) {
  console.error("Delivery packaging failed.");
  process.exit(1);
} finally {
  if (fs.existsSync(psScriptPath)) fs.unlinkSync(psScriptPath);
}
