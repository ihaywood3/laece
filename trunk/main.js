
var inputbox;
var old_text = "";
var last_search = "";
var mainbox;
var completions;
var search_running = false;
var req;
var completions;

function init ()
{
    inputbox = document.getElementById ("cmd");
    mainbox = document.getElementById ("maintext");
    completions = document.getElementById ("compl_list");
    warnings = document.getElementById("warnings");
    setInterval("interval()",500);
}

function new_XHR ()
{
    if(window.XMLHttpRequest)
    {
        var r = new XMLHttpRequest();
    }
    // branch for IE/Windows ActiveX version
    else if(window.ActiveXObject) 
    {
        try 
        {
            var r = new ActiveXObject("Msxml2.XMLHTTP");
        } 
        catch(e) 
        {
            var r = new ActiveXObject("Microsoft.XMLHTTP");
        }
    }
    return r;
}

function interval ()
{
    if (search_running)
        return;
    var new_text = inputbox.value;
    if (new_text != old_text)
    {
        old_text = new_text;
        return;
    }
    if (old_text != last_search)
    {
        // ok we have some interesting text to search on
        last_search = new_text;
        search_running = true;
        req = new_XHR ();
        req.open("POST","/completions",true);
        req.onreadystatechange = recieveCompletionsResult;
        req.send(new_text);
    }
}

function recieveCompletionsResult()
{
    recieveResult(completions,"completions");
}

function recieveResult(obj,templ)
{
    // only if req shows "loaded"
    if (req.readyState == 4) 
    {
        // only if "OK"
        if (req.status == 200) 
        {
            // can process the result
            var res = eval('('+req.responseText+')');
            var htm  = TrimPath.processDOMTemplate(templ,res);
            obj.innerHTML = htm;
        } 
        else 
        {
            alert("There was a problem retrieving the data:\n" +
                req.responseText);
        }
        search_running = false;
    }
}