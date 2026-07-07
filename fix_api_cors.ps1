# =============================================================================
# Enables CORS on API Gateway (id: sd7ds72m8g) so Flutter Web can call the
# profile and candidate endpoints from localhost/GitHub Pages.
#
# PREREQUISITE: valid, non-expired AWS credentials in ~/.aws/credentials
# or exported as env vars. Verify first with:
#   aws sts get-caller-identity
# =============================================================================
$ErrorActionPreference = "Stop"

$apiId = "sd7ds72m8g"
$region = "ap-southeast-1"
$stageName = "prod"
$apiBaseUrl = "https://$apiId.execute-api.$region.amazonaws.com/$stageName"

# HTTP API v2 did not emit CORS response headers for this API when AllowOrigins
# was configured as "*". Keep explicit browser origins and run Flutter Web on a
# fixed local port so the preflight origin matches exactly.
$allowOrigins = @(
    "http://localhost:64746",
    "http://127.0.0.1:64746",
    "https://hd-2004.github.io"
)
$allowOriginCsv = $allowOrigins -join ","
$corsResponseOrigin = $allowOrigins[0]
$allowMethods = "GET,POST,PUT,DELETE,OPTIONS"
$allowHeaders = "content-type,authorization"

$profileTestUserId = "c91a85cc-80d1-705d-996d-865a8781a144"
$preflightOrigin = "http://localhost:64746"

function Invoke-AwsCli {
    param(
        [Parameter(Mandatory = $true)]
        [string[]] $Arguments,
        [switch] $AllowFailure
    )

    $output = & aws @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0 -and -not $AllowFailure) {
        throw "aws $($Arguments -join ' ') failed:`n$output"
    }

    return @{
        ExitCode = $exitCode
        Output = ($output -join "`n")
    }
}

function Invoke-AwsJson {
    param(
        [Parameter(Mandatory = $true)]
        [string[]] $Arguments,
        [switch] $AllowFailure
    )

    $result = Invoke-AwsCli -Arguments $Arguments -AllowFailure:$AllowFailure
    if ($result.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($result.Output)) {
        return $null
    }
    return $result.Output | ConvertFrom-Json
}

function Test-CallerIdentity {
    Write-Output "Checking caller identity..."
    $identity = Invoke-AwsCli -Arguments @("sts", "get-caller-identity") -AllowFailure
    if ($identity.ExitCode -ne 0) {
        Write-Output $identity.Output
        throw "AWS credentials are invalid or expired. Refresh credentials, then run this script again."
    }
    Write-Output $identity.Output
}

function Set-HttpApiCors {
    param([Parameter(Mandatory = $true)] $HttpApi)

    Write-Output "Detected HTTP API (v2): $($HttpApi.Name). Applying CORS..."
    Invoke-AwsCli -Arguments @(
        "apigatewayv2", "update-api",
        "--api-id", $apiId,
        "--region", $region,
        "--cors-configuration",
        "AllowOrigins=$allowOriginCsv,AllowMethods=$allowMethods,AllowHeaders=$allowHeaders,MaxAge=3600"
    ) | Out-Host
    Write-Output "CORS configuration applied to HTTP API. It takes effect immediately."
}

function Get-RestResources {
    return Invoke-AwsJson -Arguments @(
        "apigateway", "get-resources",
        "--rest-api-id", $apiId,
        "--region", $region,
        "--limit", "500"
    )
}

function Find-RestResource {
    param(
        [Parameter(Mandatory = $true)] $Resources,
        [Parameter(Mandatory = $true)] [string] $Path
    )

    $resource = $Resources.items | Where-Object { $_.path -eq $Path } | Select-Object -First 1
    if ($null -eq $resource) {
        throw "Could not find REST API resource path: $Path"
    }
    return $resource
}

function Test-RestMethodExists {
    param(
        [Parameter(Mandatory = $true)] [string] $ResourceId,
        [Parameter(Mandatory = $true)] [string] $Method
    )

    $result = Invoke-AwsCli -Arguments @(
        "apigateway", "get-method",
        "--rest-api-id", $apiId,
        "--resource-id", $ResourceId,
        "--http-method", $Method,
        "--region", $region
    ) -AllowFailure
    return $result.ExitCode -eq 0
}

function Ensure-RestMethodResponseCors {
    param(
        [Parameter(Mandatory = $true)] [string] $ResourceId,
        [Parameter(Mandatory = $true)] [string] $Method,
        [string] $StatusCode = "200"
    )

    Invoke-AwsCli -Arguments @(
        "apigateway", "put-method-response",
        "--rest-api-id", $apiId,
        "--resource-id", $ResourceId,
        "--http-method", $Method,
        "--status-code", $StatusCode,
        "--response-parameters",
        "method.response.header.Access-Control-Allow-Origin=true,method.response.header.Access-Control-Allow-Headers=true,method.response.header.Access-Control-Allow-Methods=true",
        "--region", $region
    ) | Out-Host
}

function Ensure-RestIntegrationResponseCors {
    param(
        [Parameter(Mandatory = $true)] [string] $ResourceId,
        [Parameter(Mandatory = $true)] [string] $Method,
        [string] $StatusCode = "200"
    )

    $result = Invoke-AwsCli -Arguments @(
        "apigateway", "put-integration-response",
        "--rest-api-id", $apiId,
        "--resource-id", $ResourceId,
        "--http-method", $Method,
        "--status-code", $StatusCode,
        "--response-parameters",
        "method.response.header.Access-Control-Allow-Origin='$corsResponseOrigin',method.response.header.Access-Control-Allow-Headers='$allowHeaders',method.response.header.Access-Control-Allow-Methods='$allowMethods'",
        "--region", $region
    ) -AllowFailure

    if ($result.ExitCode -ne 0) {
        Write-Output "Could not attach integration response CORS for $Method on resource $ResourceId."
        Write-Output "This is expected for Lambda proxy integrations; the OPTIONS mock and HTTP API CORS paths still matter."
        Write-Output $result.Output
    } else {
        Write-Output $result.Output
    }
}

function Ensure-RestOptionsCors {
    param([Parameter(Mandatory = $true)] [string] $ResourceId)

    if (-not (Test-RestMethodExists -ResourceId $ResourceId -Method "OPTIONS")) {
        Invoke-AwsCli -Arguments @(
            "apigateway", "put-method",
            "--rest-api-id", $apiId,
            "--resource-id", $ResourceId,
            "--http-method", "OPTIONS",
            "--authorization-type", "NONE",
            "--region", $region
        ) | Out-Host
    } else {
        Write-Output "OPTIONS already exists for resource $ResourceId. Updating integration and responses..."
    }

    Invoke-AwsCli -Arguments @(
        "apigateway", "put-integration",
        "--rest-api-id", $apiId,
        "--resource-id", $ResourceId,
        "--http-method", "OPTIONS",
        "--type", "MOCK",
        "--request-templates", '{"application/json":"{\"statusCode\": 200}"}',
        "--region", $region
    ) | Out-Host

    Ensure-RestMethodResponseCors -ResourceId $ResourceId -Method "OPTIONS"
    Ensure-RestIntegrationResponseCors -ResourceId $ResourceId -Method "OPTIONS"
}

function Set-RestGatewayResponsesCors {
    foreach ($responseType in @("DEFAULT_4XX", "DEFAULT_5XX")) {
        Invoke-AwsCli -Arguments @(
            "apigateway", "put-gateway-response",
            "--rest-api-id", $apiId,
            "--region", $region,
            "--response-type", $responseType,
            "--response-parameters",
            "gatewayresponse.header.Access-Control-Allow-Origin='$corsResponseOrigin',gatewayresponse.header.Access-Control-Allow-Headers='$allowHeaders',gatewayresponse.header.Access-Control-Allow-Methods='$allowMethods'"
        ) | Out-Host
    }
}

function Set-RestApiCors {
    param([Parameter(Mandatory = $true)] $RestApi)

    Write-Output "Detected REST API (v1): $($RestApi.name). Applying CORS..."
    $resources = Get-RestResources

    $paths = @(
        "/profile",
        "/profile/{userId}",
        "/profile/email/{email}",
        "/candidate/recommend-jobs"
    )

    $resourceByPath = @{}
    foreach ($path in $paths) {
        $resourceByPath[$path] = Find-RestResource -Resources $resources -Path $path
        Write-Output "Found $path -> $($resourceByPath[$path].id)"
    }

    $methodTargets = @(
        @{ Path = "/profile"; Method = "POST" },
        @{ Path = "/profile/{userId}"; Method = "GET" },
        @{ Path = "/profile/{userId}"; Method = "PUT" },
        @{ Path = "/profile/email/{email}"; Method = "GET" },
        @{ Path = "/candidate/recommend-jobs"; Method = "POST" }
    )

    foreach ($target in $methodTargets) {
        $resourceId = $resourceByPath[$target.Path].id
        $method = $target.Method
        if (Test-RestMethodExists -ResourceId $resourceId -Method $method) {
            Write-Output "Adding CORS method response headers for $method $($target.Path)..."
            Ensure-RestMethodResponseCors -ResourceId $resourceId -Method $method
            Ensure-RestIntegrationResponseCors -ResourceId $resourceId -Method $method
        } else {
            Write-Output "Skipping $method $($target.Path): method does not exist on this REST API."
        }
    }

    foreach ($path in $paths) {
        Write-Output "Adding/updating MOCK OPTIONS for $path..."
        Ensure-RestOptionsCors -ResourceId $resourceByPath[$path].id
    }

    Write-Output "Adding CORS headers to default 4XX/5XX gateway responses..."
    Set-RestGatewayResponsesCors

    Write-Output "Deploying REST API stage '$stageName'..."
    Invoke-AwsCli -Arguments @(
        "apigateway", "create-deployment",
        "--rest-api-id", $apiId,
        "--stage-name", $stageName,
        "--region", $region
    ) | Out-Host
}

function Test-Preflight {
    param(
        [Parameter(Mandatory = $true)] [string] $Url,
        [Parameter(Mandatory = $true)] [string] $Method
    )

    Write-Output ""
    Write-Output "Verifying preflight: $Method $Url"
    curl.exe -i -X OPTIONS $Url `
        -H "Origin: $preflightOrigin" `
        -H "Access-Control-Request-Method: $Method" `
        -H "Access-Control-Request-Headers: $allowHeaders"
}

Test-CallerIdentity

$httpApi = Invoke-AwsJson -Arguments @(
    "apigatewayv2", "get-api",
    "--api-id", $apiId,
    "--region", $region
) -AllowFailure

if ($httpApi -and $httpApi.ApiId -eq $apiId) {
    Set-HttpApiCors -HttpApi $httpApi
} else {
    Write-Output "Not an HTTP API. Checking REST API..."
    $restApi = Invoke-AwsJson -Arguments @(
        "apigateway", "get-rest-api",
        "--rest-api-id", $apiId,
        "--region", $region
    )
    Set-RestApiCors -RestApi $restApi
}

Test-Preflight -Url "$apiBaseUrl/profile/$profileTestUserId" -Method "PUT"
Test-Preflight -Url "$apiBaseUrl/profile/$profileTestUserId" -Method "GET"
Test-Preflight -Url "$apiBaseUrl/candidate/recommend-jobs" -Method "POST"

Write-Output ""
Write-Output "CORS repair script finished. Confirm the responses above include Access-Control-Allow-Origin, Access-Control-Allow-Methods, and Access-Control-Allow-Headers."
