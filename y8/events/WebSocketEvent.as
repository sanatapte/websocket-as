package y8.events
{
	import flash.events.Event;
	
	public class WebSocketEvent extends Event {		
		public var data:String;
		
		public static const MESSAGE:String = "message";
		
		public function WebSocketEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false, data:String = null)
		{
			super(type, bubbles, cancelable);
			this.data = data;
		}
		
		override public function clone():Event {
			return new WebSocketEvent(super.type, super.bubbles, super.cancelable, this.data);
		}
	}
}