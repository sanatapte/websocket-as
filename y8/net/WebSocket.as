/**
* WebSocket ActionScript Client 1.0 by Alexey Y. Bondar. January 31, 2010
* http://github.com/y8/websocket-as
* @author Alexey Y. Bondar (y8 at ya dot ru), 2010.
* @see LICENSE http://github.com/y8/websocket-as/raw/master/LICENSE
*/

package y8.net {
    import com.adobe.net.URI;

    import flash.events.Event;
    import flash.events.EventDispatcher;
    import flash.events.IOErrorEvent;
    import flash.events.ProgressEvent;
    import flash.events.SecurityErrorEvent;
    import flash.net.Socket;
    import flash.system.Security;
    import flash.utils.ByteArray;

    import y8.events.WebSocketEvent;
    import y8.events.WebSocketErrorEvent;

    [Event(name="open", type="flash.events.Event")]
    [Event(name="close", type="flash.events.Event")]
    [Event(name="error", type="y8.events.WebSocketErrorEvent")]
    [Event(name="message", type="y8.events.WebSocketEvent")]
    /**
     * WebSocket class
     *
     * @author                    y8
     * @version                   1.0
     * @playerversion             Flash 9
     */
    public class WebSocket extends EventDispatcher{
        /**
         * @private
         */
        private static var WAIT:String = "waiting";

        /**
         * @private
         */
        private static var PROCESS:String = "processing";

        /**
         * @private
         */
        private static var CLOSE:String = "closing";

        /**
         * @private
         */
        private var socket:Socket;

        /**
         * @private
         */
        private var headers_buffer:String;

        /**
         * @private
         */
        private var state:String = WAIT;

        /**
         * @private
         */
        private var uri:URI;

        /**
         * @private
         */
        private var location:String;

        /**
         * @private
         */
        private var origin:String;

        /**
         * @private
         */
        private var path:String;

        /**
         * @private
         */
        private var host:String;

        /**
         * @private
         */
        private var port:Number;

        /**
         * @private
         */
        private var reading:Boolean = false;

        /**
         * @private
         */
        private var frame:ByteArray;

        /**
         * Creates a new WebSocket object.
         */
        public function WebSocket() {
            this.headers_buffer = '';
            this.reading = false;
            this.frame = new ByteArray();
            this.socket = new Socket();

            this.socket.addEventListener(Event.CONNECT, onConnect);
            this.socket.addEventListener(Event.CLOSE, onClose);
            this.socket.addEventListener(ProgressEvent.SOCKET_DATA, onData);

            this.socket.addEventListener(IOErrorEvent.IO_ERROR, onError);
            this.socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);
        }

        /**
         * Opens WebSocket connection to given uri.
         *
         * @param uri:String — WebSocket URI pointing to server, only "ws" scheme supported.
         * @param origin:String — WebSocket request origin. Set to URI of source page, where this class used.
         *
         * @event open:Event  — Dispatched after handshake complete.
         * @event close:Event — Dispatched when WebSocket connection closed.
         * @event error:WebSocketErrorEvent — Dispatched on WebSocket error
         * @event message:WebSocketEvent — Dispatched websocket dataframe recivied.
         */
        public function open(uri:String, origin:String):void {
            this.uri = new URI(uri);

            //Check for scheme. Secure not supported.
            if(this.uri.scheme.toLowerCase() != "ws") {
                dispatchError("Wrong url scheme for WebSocket: " + this.uri.scheme);
            }

            //Uri fragment not permited.
            if(this.uri.fragment) {
                dispatchError("URL has fragment component: " + uri);
            }

            //Setting connection varibles.
            this.host = this.uri.authority;
            this.port = Number(this.uri.port) || 80; //80 is default port
            this.origin = origin;
            this.path = this.uri.path || '/';        // '/' is default path

            //Saving uri for future handshake validations
            this.location = uri;

            //Force policy file loading.
            Security.loadPolicyFile("http://" + this.host + ":" + this.port + "/crossdomain.xml");

            //Open socket connection
            this.socket.connect(this.host, this.port);
        }

        /**
         * Closes WebSocket connection.
         */
        public function close():void {
            this.state = CLOSE;
            this.socket.close();
        }

        /**
         * Sends data to server
         *
         * @param data:String — data to send
         */
        public function send(data:String):void {
            if(this.state == PROCESS) {
                this.socket.writeByte(0x00);
                this.socket.writeUTFBytes(data);
                this.socket.writeByte(0xFF);
                this.socket.flush();
            } else {
                super.dispatchEvent(new WebSocketErrorEvent(WebSocketErrorEvent.ERROR, false, false, "WebSocket not ready."));
            }
        }

        /**
         * @private
         */
        private function onConnect(event:Event):void {
            this.socket.writeUTFBytes(this.handshake());
        }

        /**
         * @private
         */
        private function onClose(event:Event):void {
            super.dispatchEvent(new Event(Event.CLOSE));
        }

        /**
         * @private
         */
        private function onData(event:ProgressEvent):void {
            //Data recived, dispatching
            switch(this.state) {
                case WAIT:
                    //Bufferizing data
                    this.headers_buffer = this.headers_buffer + socket.readUTFBytes(event.bytesLoaded);
                    //Waiting for HTTP headers.
                    waitHeaders();
                    break;
                case PROCESS:
                    //Processing data-frame
                    processData();
                    break;
                case CLOSE:
                    //Do nothing
                    break;
                default:
                    throw("WebSocket in unknown state:" + state);
            }
        }

        /**
         * @private
         */
        private function onSecurityError(event:SecurityErrorEvent):void {
            super.dispatchEvent(new WebSocketErrorEvent(WebSocketErrorEvent.ERROR, false, false, event.text));
        }

        /**
         * @private
         */
        private function onError(event:IOErrorEvent):void {
            super.dispatchEvent(new WebSocketErrorEvent(WebSocketErrorEvent.ERROR, false, false, event.text));
        }

        /**
         * @private
         */
        private function waitHeaders():void {
            if(this.headers_buffer.indexOf("\r\n\r\n") >= 0) {
                //Getting heders
                var request:Array = this.headers_buffer.split("\r\n\r\n")[0].split("\r\n");
                this.headers_buffer = null;

                //Getggin response status line
                var status:String = request.shift();

                //Cheking response status
                if(status != "HTTP/1.1 101 Web Socket Protocol Handshake") {
                    dispatchError("Wrong WebSocket handshake respons status: " + status);
                    this.socket.close();
                }

                //Parsing headers
                var headers:Object = parseHeaders(request);

                //Checking websocket-origin to match origin
                if(headers['websocket-origin'].toLowerCase() != this.origin.toLowerCase()) {
                    dispatchError("Websocket-Origin mismatch. Expected: " + this.origin + ", got: " + headers['websocket-origin']);
                    this.socket.close();
                }

                //Checking websocket-location to match location
                if(headers['websocket-location'] != this.location) {
                    dispatchError("WebSocket-Location mismatch. Expected: " + this.location + ", got: " + headers['websocket-location']);
                    this.socket.close();
                }

                //Connection established.
                this.state = PROCESS;
                super.dispatchEvent(new Event(Event.OPEN));
            }
        }

        /**
         * @private
         */
        private function parseHeaders(request:Array):Object {
            var headers:Object = new Object();
            for each (var line:String in request) {
                var header:Array = line.split(/:\s+/);
                headers[header[0].toLowerCase()] = header[1];
            }
            return headers;
        }

        /**
         * @private
         */
        private function handshake():String {
            var handshake:Array = new Array();

            handshake.push("GET " + this.path + " HTTP/1.1");
            handshake.push("Upgrade: WebSocket");
            handshake.push("Connection: Upgrade");
            handshake.push("Host: " + this.host);
            handshake.push("Origin: " + this.origin);
            handshake.push("\r\n");

            return handshake.join("\r\n");
        }

        /**
         * @private
         */
        private function processData():void {
            while (this.socket.bytesAvailable) {
                var byte:uint = socket.readUnsignedByte();

                if(byte == 0x00) {
                    if(this.reading) {
                        dispatchError("Unexpected data frame begin mark while reading");
                        this.socket.close();
                    }
                    this.frame.length = 0;
                    this.reading = true;
                } else if (byte == 0xFF) {
                    if(!this.reading) {
                        dispatchError("Data frame must strart with begin mark, but got end mark");
                        this.socket.close();
                    }
                    this.frame.position = 0;
                    super.dispatchEvent(new WebSocketEvent(WebSocketEvent.MESSAGE, false, false, this.frame.readUTFBytes(frame.length)));
                    this.reading = false;
                } else {
                    if(reading) {
                        this.frame.writeByte(byte);
                    } else {
                        dispatchError("Data frame must starts with begin mark.");
                        this.socket.close();
                    }
                }
            }
        }

        /**
         * @private
         */
        private function dispatchError(text:String):void {
            super.dispatchEvent(new WebSocketErrorEvent(WebSocketErrorEvent.ERROR, false, false, text));
        }

        /**
         * @private
         */
        private function destory():void {
            this.socket.removeEventListener(Event.CONNECT, onConnect);
            this.socket.removeEventListener(Event.CLOSE, onClose);
            this.socket.removeEventListener(ProgressEvent.SOCKET_DATA, onData);

            this.socket.removeEventListener(IOErrorEvent.IO_ERROR, onError);
            this.socket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);
            this.socket = null;
        }
    }
}