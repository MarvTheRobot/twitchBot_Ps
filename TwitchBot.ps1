function Start-Bot {
	[cmdletbinding()]
	param(
		$Server = 'irc.chat.twitch.tv',
		$Port = 6697,
		$UserName = 'marvro_bot',
		$Channel = 'marvrobot'
	)

	$AuthToken = Get-Content -Path $PSCommandPath.Replace('TwitchBot.ps1', 'token.txt')

	Write-Verbose "Connecting stream"
	#Establish server connection (server + port)	
	$client = New-Object -TypeName System.Net.Sockets.TcpClient
	$client.NoDelay = $true
	$client.SendBufferSize = 81920
	$client.ReceiveBufferSize = 81920
	$client.Connect($server, $port)

	$clientStream = $client.GetStream()
	$sslStream    = New-Object -TypeName System.Net.Security.SslStream($clientStream, $false)
	$sslStream.AuthenticateAsClient($server)

	$outputStream = New-Object -TypeName System.IO.StreamWriter($sslStream)
	$outputStream.NewLine = "`r`n"
	$inputStream  = New-Object -TypeName System.IO.StreamReader($sslStream)

	Write-Verbose "Trying to log in"
	if($authToken -isnot [object]){throw "No auth token"}
	#Actually log in with username and authtoken
	$outputStream.WriteLine("PASS $AuthToken")
	$outputStream.WriteLine("NICK $UserName")
	$outputStream.WriteLine("CAP REQ :twitch.tv/membership twitch.tv/tags twitch.tv/commands")
	$outputStream.Flush()

	Start-Sleep -Seconds 1
	$outputStream.WriteLine("JOIN #$Channel")
	$outputStream.Flush()

	"Client Connected $($client.Connected)"
	While ($client.Connected) {
		While ($client.GetStream().DataAvailable -or $inputStream.Peek() -ne -1 ){
			try {
				Write-Output $inputStream.Peek()
				$message = $inputStream.ReadLine()
				Write-Output $message
				if($Message -eq 'PING :tmi.twitch.tv') {
					$response = 'PONG :tmi.twitch.tv'
					Write-Output $response
					$outputStream.WriteLine($response)
					$outputStream.Flush()

				}elseif ($message.EndsWith('!project')) {
					$outputStream.WriteLine("PRIVMSG #$channel :'We are trying, and almost succeeding, building a TwitchBot in PowerShell'")
					$outputStream.Flush()
				}
			}
			catch {
				Throw "It broken: $_"	
			}
		}
	}
	$inputStream.Close()
	$outputStream.Close()
	$client.Close()
}