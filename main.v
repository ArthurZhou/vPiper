module main

import os
import net.websocket
import term
import encoding.base64
import time
import json
import rand
import log

__global (
	s mut websocket.Server
	ws mut websocket.Client
	server_addr string
	host_port int
	my_name string
	my_uuid string
	logger mut log.Log
)

struct Context {
	msg string
	name string
	uuid string
}

fn main() {
	logger = &log.Log{}
	logger.set_output_level(log.Level.disabled)
	server_addr = 'ws://localhost:28173'
	host_port = 28174
	my_name = 'az'
	my_uuid = rand.uuid_v4()

	go start_client()
	start_server()
}

fn start_client() {
	exec_client(server_addr) or {
		return
	}
}

fn exec_client(server string) ! {
	ws = client(server) or {
		logger.debug(err.str())
		return
	}
	defer {
		unsafe {
			ws.free()
		}
	}
	println(term.green('connected as ${ws.id}'))
	println(term.gray('server: ${server}  name: ${my_name}  uuid: ${my_uuid}'))
	go alive(mut ws)
}

fn client(server string) !&websocket.Client {
	ws = websocket.new_client(server)!
	ws.logger.set_level(log.Level.disabled)

	// mut ws := websocket.new_client('wss://echo.websocket.org:443')?
	// use on_open_ref if you want to send any reference object
	ws.on_open(fn (mut ws websocket.Client) ! {
		println(term.green('remote server ready'))
	})

	// use on_close_ref if you want to send any reference object
	ws.on_close(fn (mut ws websocket.Client, code int, reason string) ! {
		println(term.green('remote server closed'))
		exit(0)
	})

	// on_message_ref, broadcast all incoming messages to all clients except the one sent it
	ws.on_message_ref(fn (mut ws websocket.Client, msg &websocket.Message, _ voidptr) ! {
		message := json.decode(Context, base64.decode_str(msg.payload.bytestr()))!
		println(term.bg_rgb(8, 15, 19, term.rgb(195, 195, 195, ' ${time.now()} [${message.name} (${message.uuid})] > ${message.msg} ')))
		for i, _ in s.clients {
			mut c := s.clients[i]
			c.client.write(base64.encode_str(json.encode(Context{message.msg, message.name, message.uuid})).bytes(), websocket.OPCode.text_frame) or { panic(err) }
		}
	}, ws)

	ws.connect() or {
		println(term.red('connect error: ${err}'))
		return err
	}
	spawn ws.listen()
	println(term.yellow('Type message and press Enter to send'))
	return ws
}

fn start_server() {
	go start_input()
	server() or {
		return
	}
}

fn server() ! {
	println('starting server')
	s = websocket.new_server(.ip6, host_port, '')
	defer {
		unsafe {
			s.free()
		}
	}
	// Make that in execution test time give time to execute at least one time
	s.ping_interval = 100
	s.on_connect(fn (mut s websocket.ServerClient) !bool {
		// Here you can look att the client info and accept or not accept
		// just returning a true/false
		if s.resource_name != '/' {
			return false
		}
		return true
	})!

	// on_message_ref, broadcast all incoming messages to all clients except the one sent it
	s.on_message_ref(fn (mut ws_local websocket.Client, msg &websocket.Message, mut m websocket.Server) ! {
		message := json.decode(Context, base64.decode_str(msg.payload.bytestr()))!
		println(term.bg_rgb(8, 15, 19, term.rgb(195, 195, 195, ' ${time.now()} [${message.name} (${message.uuid})] > ${message.msg} ')))
		for i, _ in m.clients {
			mut c := m.clients[i]
			if c.client.state == .open && c.client.id != ws_local.id {
				c.client.write(msg.payload, websocket.OPCode.text_frame) or { panic(err) }
			}
		}
		ws.write_string(base64.encode_str(json.encode(Context{message.msg, message.name, message.uuid}))) or {
			logger.debug(err.str())
		}
	}, s)

	s.on_close(fn (mut ws websocket.Client, code int, reason string) ! {
		println(term.green('client (${ws.id}) closed connection'))
	})

	s.listen() or { println(term.red('error on server listen: ${err}')) }
	println("listen done")
}

fn alive(mut ws websocket.Client) {
	for {
		ws.ping() or { return }
		time.sleep(5e+9)
	}
}

fn start_input() {
	input() or {
		return
	}
}

fn input() ! {
	mut startup := 0
	for {
		line := os.input("")
		if line == '' {
			if startup == 1 {
				print("Exit? [Y/n]: ")
				sure := os.get_line()
				if sure == 'Y' {
					break
				}
			}
		} else {
			ws.write_string(base64.encode_str(json.encode(Context{line, my_name, my_uuid}))) or {
				logger.debug(err.str())
			}
			for i, _ in s.clients {
				mut c := s.clients[i]
				c.client.write(base64.encode_str(json.encode(Context{line, my_name, my_uuid})).bytes(), websocket.OPCode.text_frame) or { panic(err) }
			}
		}
	}
	ws.close(1000, 'normal') or {
		logger.debug(err.str())
	}
}