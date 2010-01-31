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