# Буфер обмена Windows с двумя форматами: Text (TSV для Excel) + HTML (таблица с рамками для Word/Outlook).
# OSC 52 и lemonade переносят только текст, поэтому nvim шлёт сюда "text\0html" через `ssh -W 127.0.0.1:2490 winhost`.
# Живёт в интерактивной сессии пользователя (задача nvim-clip-html, at logon; регистрация — register-clip-html.ps1): из сессии sshd буфер рабочего стола не виден.
# Ответ клиенту: "ok" после записи буфера, иначе "err: <причина>".
Add-Type -AssemblyName System.Windows.Forms

function ConvertTo-CfHtml([string]$fragment) {
	$utf8 = [Text.Encoding]::UTF8
	$pre = "<html><body>`r`n<!--StartFragment-->"
	$post = "<!--EndFragment-->`r`n</body></html>"
	$tpl = "Version:0.9`r`nStartHTML:{0:D10}`r`nEndHTML:{1:D10}`r`nStartFragment:{2:D10}`r`nEndFragment:{3:D10}`r`n"
	$hlen = $utf8.GetByteCount(($tpl -f 0, 0, 0, 0))
	$sf = $hlen + $utf8.GetByteCount($pre)
	$ef = $sf + $utf8.GetByteCount($fragment)
	$eh = $ef + $utf8.GetByteCount($post)
	$utf8.GetBytes(($tpl -f $hlen, $eh, $sf, $ef) + $pre + $fragment + $post)
}

$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 2490)
$listener.Start()
while ($true) {
	$client = $listener.AcceptTcpClient()
	try {
		$stream = $client.GetStream()
		$buf = [IO.MemoryStream]::new()
		$stream.CopyTo($buf)
		$parts = [Text.Encoding]::UTF8.GetString($buf.ToArray()).Split([char]0, 2)
		if ($parts.Count -ne 2) { throw "ожидалось text\0html" }
		$data = [Windows.Forms.DataObject]::new()
		$data.SetData([Windows.Forms.DataFormats]::UnicodeText, $parts[0])
		$data.SetData([Windows.Forms.DataFormats]::Html, [IO.MemoryStream]::new([byte[]](ConvertTo-CfHtml $parts[1])))
		[Windows.Forms.Clipboard]::SetDataObject($data, $true)
		$reply = "ok"
	} catch {
		$reply = "err: $($_.Exception.Message)"
	}
	try {
		$bytes = [Text.Encoding]::UTF8.GetBytes($reply)
		$stream.Write($bytes, 0, $bytes.Length)
	} finally {
		$client.Close()
	}
}
