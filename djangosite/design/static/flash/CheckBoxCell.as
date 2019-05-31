import mx.core.UIComponent;
import mx.controls.CheckBox;
class CheckBoxCell extends UIComponent
{
	private var check:MovieClip;
	private var listOwner:MovieClip;
	// the reference we receive to the list
	private var getCellIndex:Function;
	// the function we receive from the list
	private var getDataLabel:Function;
	// the function we receive from the list
	private static var PREFERRED_HEIGHT = 16;
	private static var PREFERRED_WIDTH = 20;
	public function CheckBoxCell ()
	{
	}
	public function createChildren (Void):Void
	{
		check = createObject ("CheckBox", "check", 1, {styleName:this, owner:this});
		check.addEventListener ("click", this);
		size ();
	}
	public function size (Void):Void
	{
		check.setSize (500, PREFERRED_WIDTH);
		check._x = (10);
		check._y = (__height - PREFERRED_HEIGHT) / 2;
	}
	public function setValue (str:String, item:Object, sel:Boolean):Void
	{
		check._visible = (item != undefined);
		check.selected = item.selected;
		check.label = item.label;
	}
	public function getPreferredHeight (Void):Number
	{
		return PREFERRED_HEIGHT;
	}
	public function getPreferredWidth (Void):Number
	{
		return PREFERRED_WIDTH;
	}
	public function click ()
	{
	
		listOwner.replaceItemAt (getCellIndex ().itemIndex, {label:check.label, selected:check.selected});
		_root.itemClicked.text = check.label  + " is selected"
	}

}
