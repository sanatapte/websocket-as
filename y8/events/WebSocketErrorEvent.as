/**
* WebSocket ActionScript Client 1.0 by Alexey Y. Bondar. January 31, 2010
* http://github.com/y8/websocket-as
* @author Alexey Y. Bondar (y8 at ya dot ru), 2010.
* @see LICENSE http://github.com/y8/websocket-as/raw/master/LICENSE
*/
package y8.events
{
    import flash.events.Event;

    public class WebSocketErrorEvent extends Event {
        public var error:String;

        public static const ERROR:String = "error";

        public function WebSocketErrorEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false, error:String = null)
        {
            super(type, bubbles, cancelable);
            this.error = error;
        }

        override public function clone():Event {
            return new WebSocketErrorEvent(super.type, super.bubbles, super.cancelable, this.error);
        }
    }
}