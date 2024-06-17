defmodule Operations do
  def add(content) do
    content = content <> "\n"
    File.write("./open.md", content, [:append])

    IO.puts("Recurso adicionado com sucesso!")
  end

  def execute(args) when length(args) == 1, do: execute([List.first(args), nil])
    
  def execute([command, link]) do
    Kernel.apply(__MODULE__, String.to_atom(command), [link])
  end

  def take(_) do
    {:ok, content} = File.read("./open.md")
    content = String.split(content, "\n") 
    content_length = Enum.count(content)

    n = Enum.random(0..content_length - 1)

    link = Enum.at(content, n)

    IO.puts(link)
  end
end

defmodule Client do
  def fetch(host, path) do
    host = if is_binary(host), do: String.to_charlist(host), else: host
    path = if is_binary(path), do: String.to_charlist(path), else: host

    cert_file = String.to_charlist("/etc/ssl/certs/ca-certificates.crt")

    {:ok, response} = handle_request(host, path, cert_file)

    response
  end

  defp handle_request(host, path, cert_file) do
    :ssl.start()

    {:ok, socket} = 
      :ssl.connect(host, 443, [
        {:verify, :verify_peer},
        {:cacertfile, cert_file},
        {:active, false},
        {:customize_hostname_check, [
          {:match_fun, :public_key.pkix_verify_hostname_match_fun(:https)}
        ]}
      ], 5000)

    request = "GET #{path} HTTP/1.1\r\nHost: #{host}\r\naccept: */*\r\nUser-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3\r\n\r\n"

    :ok = :ssl.send(socket, request)
    {:ok, response} = :ssl.recv(socket, 0, 5000)
    :ok = :ssl.close(socket)

    response = cond do
      String.starts_with?(to_string(response), "HTTP/1.1 301") ->
        [location] = Regex.run(~r/Location:\s*(.*)/, to_string(response), capture: :first)
        [_, url] = String.split(location, " ")
        sanitized_url = String.replace(url, "\r", "")

        IO.inspect(sanitized_url)

        uri = URI.parse(sanitized_url)
        path = "#{uri.path}?#{uri.query}"
        Client.fetch(uri.host, path)

        true -> 
          {:ok, response}
    end

    {:ok, response}
  end
end

result = Client.fetch("youtube.com", "/watch?v=ymRqYz-Mxnw")

IO.inspect(result)

args = System.argv()

if Enum.count(args) > 2 do
  raise ~s(You should choose either "add" or "remove", follwed by a content.)

  exit 1
end

Operations.execute(args)
