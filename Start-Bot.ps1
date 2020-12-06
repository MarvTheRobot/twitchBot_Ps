function Start-Bot {
	[cmdletbinding()]
	param(
		$Server = 'irc.chat.twitch.tv',
		$Port = 6697,
		$UserName = 'marvro_bot',
		$Channel = 'marvrobot'
	)

	# This needs fixing as it's trash and ugly
	$AuthToken = Get-Content -Path $PSCommandPath.Replace('Start-Bot.ps1', 'token.txt')

	Write-Verbose "Connecting stream"
	$client = New-Object -TypeName System.Net.Sockets.TcpClient
	$client.NoDelay = $true
	$client.SendBufferSize = 81920
	$client.ReceiveBufferSize = 81920
	$client.Connect($server, $port)

	$clientStream = $client.GetStream()
	$sslStream    = New-Object -TypeName System.Net.Security.SslStream($clientStream, $false)
	$sslStream.AuthenticateAsClient($server)

	# Move to module level properties
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
				$message = ConvertFrom-TwitchMessage( $inputStream.ReadLine() )
				switch ($message.Command) {
					'PING' {
						Write-Output "You've been PING'd"
						$response = 'PONG :tmi.twitch.tv'
						Write-Output "You have PONG'd"
						$outputStream.WriteLine($response)
						$outputStream.Flush()
					}
					# Handle the message
					'PRIVMSG' {
						Write-Output $message
						$response = Get-PrivateMessageResponse($message.Content)
						if(-not ([string]::IsNullOrEmpty($response))){
							$outputStream.WriteLine("PRIVMSG #$channel :'$response'")
							$outputStream.Flush()
						}
					}
					Default {	
						$message
					}
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

function ConvertFrom-TwitchMessage {
	[cmdletbinding()]
	param(
		[string]$Message
	)


	$irctagregex = [Regex]::new('^(?:@([^ ]+) )?(?:[:]((?:(\w+)!)?\S+) )?(\S+)(?: (?!:)(.+?))?(?: [:](.+))?$')
	$match = $irctagregex.Match($Message) #tags = 1
	$props = @{
		Prefix = $match.Groups[2].Value
		User = $match.Groups[3].Value
		Command = $match.Groups[4].Value
		Params = $match.Groups[5].Value
		Content = $match.Groups[6].Value
	}
	$returnObj = New-Object -TypeName PsObject -Property $props
	Write-Output $returnObj
}


function Get-PrivateMessageResponse {
	[cmdletbinding()]
	param(
		[string]$Message
	)
	if ($Message.StartsWith('!')) {
		Write-Verbose "Command received"
		$Message     = $Message.TrimStart('!')
		$commandFile = $PSCommandPath.Replace('Start-Bot.ps1','Commands.json')
		$commands    = Get-Content -Path $commandFile -Raw | ConvertFrom-Json -Depth 5
		$commands.$Message
	}
}

