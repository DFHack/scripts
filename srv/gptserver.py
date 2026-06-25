import openai
import socket
import json
import signal
import sys

# Read API key from file
with open("../../../dfhack-config/oaak.txt", "r") as file:
    api_key = file.read().strip()

print("Proceeding with API key froam oaak.txt.")

openai.api_key = api_key

print("Starting server on port 5001... press control-C to exit.")

serversocket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
serversocket.bind(("localhost", 5001))
serversocket.listen(1)

# Set a timeout for the accept() operation
serversocket.settimeout(1)

# Define signal handler
def signal_handler(sig, frame):
    print('Stopping the server...')
    serversocket.close()
    sys.exit(0)

# Register the signal handler
signal.signal(signal.SIGINT, signal_handler)

model_to_use = "text-davinci-003"

if len(sys.argv) > 1:
    model_selection = sys.argv[1]

    if model_selection == "-gpt3":
        model_to_use = "gpt-3.5-turbo"
        print("using gpt-3.5-turbo")
    elif model_selection == "-gpt4":
        model_to_use = "gpt-4"
        print("using gpt-4")
    elif model_selection == "help" or model_selection == "-help" or model_selection == "--help":
        print("`python gptserver.py` defaults to fast, cheap, legacy AI engine `text-davinci-003`")
        print("Valid options:")
        print("  -gpt3 (uses slower, pricier `gpt-3.5-turbo` model)")
        print("  -gpt4 (uses MUCH slower, MUCH pricier `gpt-4` model)")
        print("Note: we found gpt4 gave by far the best results!")
    else:
        print("Invalid argument(s), aborting.")
        sys.exit(1)
else:
    print("Defaulting to model: `text-davinci-003`. Use -gpt3 or -gpt4 args for alternates. -help for details!")

while True:
    try:
        (conn, address) = serversocket.accept()

        if address[0] != '127.0.0.1':
            print('Attempt to connect from remote address was detected! Closing server. Remote address and NAT port were: ', address)
            sys.exit(1)

        data = conn.recv(1024*10)
        data = data.decode("utf-8")
        data = json.loads(data)

        if "prompt" in data:
            prompt = data["prompt"]
            print("Sending request for prompt: " + prompt)
            if model_to_use == "gpt-4" or model_to_use == "gpt-3.5-turbo":
                response = openai.ChatCompletion.create(
                    model=model_to_use,
                    messages=[
                        {
                            "role": "user",
                            "content": prompt
                        }
                    ],
                    temperature=1,
                    max_tokens=3000,
                    top_p=1,
                    frequency_penalty=0,
                    presence_penalty=0
                )

                response_text = response.choices[0].message.content.strip() + "\n"
                print("Got reponse: " + response_text)
                conn.sendall(response_text.encode("utf-8"))
                conn.close()

            elif model_to_use == "text-davinci-003":
                response = openai.Completion.create(
                    engine="text-davinci-003",
                    prompt=prompt,
                    max_tokens=3000
                )

                response_text = response.choices[0].text.strip() + "\n"
                print("Got reponse: " + response_text)
                conn.sendall(response_text.encode("utf-8"))
                conn.close()
            else:
                conn.close()

    except socket.timeout:
        # In case of timeout, just move on to the next loop iteration
        continue
    except KeyboardInterrupt:
        print("\nInterrupted by keyboard")
        break

serversocket.close()
