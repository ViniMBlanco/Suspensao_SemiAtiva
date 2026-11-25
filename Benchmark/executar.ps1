param(
    [string]$FonteV3 = (Join-Path $PSScriptRoot 'dados')
)

$ErrorActionPreference = 'Stop'
if (-not ((Test-Path -LiteralPath (Join-Path $FonteV3 'sinais_lombada.csv.gz')) -or
          (Test-Path -LiteralPath (Join-Path $FonteV3 'sinais_lombada.csv')))) {
    throw 'Os CSVs da campanha V3 são necessários para reproduzir o benchmark.'
}

Add-Type -Path (Join-Path $PSScriptRoot 'Simulacao.cs')
$destino = Join-Path $PSScriptRoot 'resultados'
New-Item -ItemType Directory -Force -Path $destino | Out-Null
[BenchmarkCdc]::Executar((Resolve-Path -LiteralPath $FonteV3).Path, $destino)

$metricas = Import-Csv -LiteralPath (Join-Path $destino 'metricas.csv')
$invariante = [Globalization.CultureInfo]::InvariantCulture
$resumo = $metricas | Group-Object cenario,modelo,tau_ms | ForEach-Object {
    $ensaios = $_.Group
    $primeiro = $ensaios[0]
    [pscustomobject]@{
        cenario = $primeiro.cenario
        modelo = $primeiro.modelo
        tau_ms = $primeiro.tau_ms
        n_ensaios = $ensaios.Count
        rms_aceleracao_m_s2 = ($ensaios.rms_aceleracao_m_s2 | Measure-Object -Average).Average.ToString($invariante)
        rms_carga_N = ($ensaios.rms_carga_N | Measure-Object -Average).Average.ToString($invariante)
        media_curso_max_cm = ($ensaios.curso_max_cm | Measure-Object -Average).Average.ToString($invariante)
        media_sem_contato_ms = ($ensaios.sem_contato_ms | Measure-Object -Average).Average.ToString($invariante)
        n_ensaios_sem_contato = @($ensaios | Where-Object { [double]$_.sem_contato_ms -gt 0 }).Count
    }
}
$resumo | Export-Csv -LiteralPath (Join-Path $destino 'resumo.csv') -NoTypeInformation
