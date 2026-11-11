# Keeps a file of the old folder open, so that Windows refuses to rename the folder.
$global:verrou = [IO.File]::Open((Join-Path $docs 'Claude-Travail\report.txt'), 'Open', 'Read', 'None')
