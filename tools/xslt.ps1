# Apply an XSLT 1.0 stylesheet using .NET's XslCompiledTransform.
#
# The only XSLT processor guaranteed present on a Windows machine with no
# extra installs. If you have xsltproc or Saxon, either will do the same job
# and support XSLT 2.0/3.0; this exists so that the pipeline works out of the
# box.
#
#   powershell -File tools/xslt.ps1 -Xml out/hamlet.tei.xml `
#              -Xsl xslt/tei-to-html.xsl -Out out/hamlet.tei.html [-Witness copyb]

param(
  [Parameter(Mandatory=$true)][string]$Xml,
  [Parameter(Mandatory=$true)][string]$Xsl,
  [Parameter(Mandatory=$true)][string]$Out,
  [string]$Witness = "copya",
  [string]$Layout = "opening"
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Xml | Out-Null

$xml = (Resolve-Path $Xml).Path
$xsl = (Resolve-Path $Xsl).Path
$outDir = Split-Path -Parent $Out
if ($outDir -and -not (Test-Path $outDir)) {
  New-Item -ItemType Directory -Force -Path $outDir | Out-Null
}

$settings = New-Object System.Xml.Xsl.XsltSettings($false, $false)
$resolver = New-Object System.Xml.XmlUrlResolver
$transform = New-Object System.Xml.Xsl.XslCompiledTransform
$transform.Load($xsl, $settings, $resolver)

$xsltArgs = New-Object System.Xml.Xsl.XsltArgumentList
$xsltArgs.AddParam("witness", "", $Witness)
$xsltArgs.AddParam("layout", "", $Layout)

$readerSettings = New-Object System.Xml.XmlReaderSettings
$readerSettings.DtdProcessing = [System.Xml.DtdProcessing]::Ignore
$reader = [System.Xml.XmlReader]::Create($xml, $readerSettings)

$writerSettings = $transform.OutputSettings.Clone()
$writerSettings.Encoding = New-Object System.Text.UTF8Encoding($false)
$writer = [System.Xml.XmlWriter]::Create($Out, $writerSettings)

try {
  $transform.Transform($reader, $xsltArgs, $writer)
} finally {
  $writer.Close()
  $reader.Close()
}

Write-Output "transformed $Xml -> $Out (witness $Witness, layout $Layout)"
