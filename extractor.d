import std.conv;
import std.file;
import std.exception;
import std.path;
import std.stdio;
import std.string;

import ae.sys.windows;

import win32.windows;
import win32.commctrl;

void main()
{
	HWND hMain;
	foreach (h; windowIterator("#32770", null))
		if (h.getWindowText.startsWith("MMTool Aptio- "))
		{
			hMain = h;
			break;
		}
	enforce(hMain, "Can't find MMTool window");

	DWORD pid;
	GetWindowThreadProcessId(hMain, &pid);
	auto hProcess = wenforce(OpenProcess(
		PROCESS_VM_OPERATION | PROCESS_VM_READ | PROCESS_VM_WRITE | PROCESS_QUERY_INFORMATION,
		FALSE, pid));

	auto hList = hMain.FindWindowEx(null, "SysListView32", "List3");
	enforce(hList, "Can't find module listbox");
	enforce(hList.IsWindowVisible(), "Module listbox not visible - please select Extract tab");

	auto count = hList.ListView_GetItemCount();
	writefln("%d modules.", count);
	enforce(count, "No modules to extract");

	auto hTabs = wenforce(hMain.FindWindowEx(null, "#32770", "Caption"));
	auto hTab  = wenforce(hTabs.FindWindowEx(null, "#32770", "Extract"));
	auto hDest = wenforce(hTab .FindWindowEx(null, "Edit"  , null     ));
	auto hCmd  = wenforce(hTab .FindWindowEx(null, "Button", "Extract"));

	auto dir = hMain.getWindowText()["MMTool Aptio- ".length..$].stripExtension();
	if (!dir.exists) dir.mkdir();

	auto buf  = RemoteProcessVar!(TCHAR[1024])(hProcess);
	auto item = RemoteProcessVar!LVITEM       (hProcess);

	string getListItem(uint iItem, uint iSubItem)
	{
		item.local.iItem = iItem;
		item.local.iSubItem = iSubItem;
		item.local.mask = LVIF_TEXT;
		item.local.pszText = buf.remotePtr.ptr;
		item.local.cchTextMax = buf.local.length;
		item.write();
		wenforce(hList.ListView_GetItem(item.remotePtr));
		item.read();
		buf.read();

		return to!string(buf.local[0..buf.local[0..item.local.cchTextMax].indexOf(0)]);
	}

	hList.SendMessage(WM_KEYDOWN, VK_HOME, 0);

	foreach (n; 0..count)
	{
		auto volume   = getListItem(n, 0);
		auto index    = getListItem(n, 1);
		auto fileName = getListItem(n, 2);
		auto name = volume ~ "-" ~ index;
		if (fileName.length)
			name ~= "-" ~ fileName;
		writefln("Item %d: %s", n, name);

		//hList.ListView_SetItemState(-1, 0                         , 0);
		//hList.ListView_SetItemState( n, LVIS_FOCUSED|LVIS_SELECTED, LVIS_FOCUSED|LVIS_SELECTED);

		auto dest = dir.absolutePath.buildPath(name ~ ".bin");
		auto tdest = dest.to!(TCHAR[]);
		hDest.SendMessage(WM_SETTEXT, 0, cast(LPARAM)tdest.ptr);

		hCmd.SendMessage(BM_CLICK, 0, 0);

		hList.SendMessage(WM_KEYDOWN, VK_DOWN, 0);
	}
}

