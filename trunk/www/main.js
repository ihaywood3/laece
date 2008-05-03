/*  This is the main JavaScript module for laece
*   Copyright (C) 2007 Ian Haywood
*
*   This program is free software: you can redistribute it and/or modify
*   it under the terms of the GNU General Public License as published by
*   the Free Software Foundation, either version 3 of the License, or
*   (at your option) any later version.
*
*   This program is distributed in the hope that it will be useful,
*   but WITHOUT ANY WARRANTY; without even the implied warranty of
*   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*   GNU General Public License for more details.
*
*   You should have received a copy of the GNU General Public License
*   along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

// called when a key is pressed, anywhere

function OnGlobalKeyDown(event)
{
    var key = event.key().string;
    switch (key)
    {
        case "KEY_F2":
                if (document.forms.length > 1)
        {
            event.stop ();
            if (OnSecondFormSubmit(event))
            document.forms[1].submit ();
        }
        break;
    }
}


function init (event)
{
    setInterval("OnInterval()",500);
    connect(document,"onkeydown",OnGlobalKeyDown);
    var ac_fields = getElementsByTagAndClassName("input","autocomplete");
    for (i=0;i<ac_fields.length;i++)
    {
        setNodeAttribute(ac_fields[i],"autocomplete","off");
        connect(ac_fields[i],"onkeydown",OnAutoKeyDown);
        ac_fields[i].old_text = "";
        ac_fields[i].search_running = false;
        ac_fields[i].last_search = "";
        ac_fields[i].completions = [];
        ac_fields[i].selected = -1;
        insertSiblingNodesAfter(ac_fields[i],DIV({'id':ac_fields[i].name+"_list"},null));
        appendChildNodes(ac_fields[i].form,INPUT({name:ac_fields[i].name+'_data',type:'hidden',value:''}));
    }
    if (document.forms.length>1)
    {
        connect(document.forms[1],'onsubmit',OnSecondFormSubmit);
        init_MIDAS();
        document.forms[1].elements[0].focus ();
    }
    else
    {
        document.forms[0].elements[0].focus ();
    }
}

window.onload = init; // can't use MochiKit yet, it's not loaded.


function OnSecondFormSubmit (event)
{
    var e = document.forms[1].elements;
 
    OnMidasSubmit (event);
    valid = true;
    for (i=0;i<e.length;i++)
    {
        valid = valid && checkValidity(e[i]);
    }
    return valid;
}

// check the validity of field in the second form
function checkValidity (field)
{
    if (validity_data[field.name])
    {
        if (validity_data[field.name].regexp.exec (field.value) || (field.value.length == 0 && ! validity_data[field.name].required))
            return true;
        else
        {
            elem = $(field.name+'_error');
            if (elem && hasElementClass (elem,'invisible'))
            {
                removeElementClass(elem,'invisible');
                addElementClass(elem,'error');
            }
            return false;
        }
    }
    return true; // assume valid as we can't check
}

// called every interval
function OnInterval ()
{
    if (MochiKit.DOM.getElement('edit_area')) // I don't understand why this needs to be done, but it does
         MochiKit.DOM.getElement('edit_area').contentWindow.document.designMode = "on";
    var ac_fields = MochiKit.DOM.getElementsByTagAndClassName("input","autocomplete");
    for (i=0;i<ac_fields.length;i++)
    {
        var ac = ac_fields[i];
        if (! ac.search_running)
        {
            var pat_id = ac.form.elements["pat_id"].value;
            ac.new_text = ac.value;
            if (ac.new_text != ac.old_text)
            {
                ac.old_text = ac.new_text;
            }
            else if (ac.old_text != ac.last_search)
            {
                // ok we have some interesting text to search on
                ac.last_search = ac.new_text;
                ac.search_running = true;
                var xhr = MochiKit.Async.doSimpleXMLHttpRequest("/patient/"+pat_id+"/completions", {"compl_text": ac.new_text,"widget":ac.name});
                xhr.addCallback(recieveResult, ac);
                xhr.addErrback(recieveError, ac);
            }
        }
    }
}

function recieveError(ac, req)
{
    ac.search_running = false;
}


function recieveResult(ac, req)
{
    // only if req shows "loaded"
    if (req.readyState == 4) 
    {
        // only if "OK"
        ac.search_running = false;
        if (req.status == 200 && req.responseText.length > 3) 
        {
            // can process the result
            ac.completions = map(function (x)
            {
                var y = x.split("|");
                var item = LI();
                item.innerHTML = y[2];
                return {'data':y[0],'string':y[1],'li':item,path:y[3]}
            },filter(null,req.responseText.split("\n")));
            var comp_node = ac.name+"_list";
            swapDOM(comp_node,DIV({'id':comp_node,'class':'compl_list'},[UL(null,map(function (x) {return x.li;},ac.completions))]));
            if (ac.completions.length > 0)
            {
                ac.selected = 0;
                LineSelect(ac);
            }
            else
                ac.selected = -1;
        }
        else
        {
            if (ac.selected > -1)
            {
                comp_node = ac.name+"_list";
                swapDOM(comp_node,DIV({id:comp_node}));
                ac.selected = -1;
                ac.completions = [];
            }
        } 
    }
}

function OnAutoKeyDown (event)
{
    ac = event.src ();
    switch (event.key ().string)
    {
    case "KEY_ARROW_DOWN":
        if (ac.selected<ac.completions.length-1 && ac.completions.length>0)
        {
            LineUnselect(ac);
            ac.selected++;
            LineSelect(ac); 
            event.stop();
        }
        break;
    case "KEY_ARROW_UP":
        if (ac.selected>0)
        {
            LineUnselect(ac);
            ac.selected--;
            LineSelect(ac);
            event.stop();
        }
        break;
    case "KEY_ENTER":
    case "KEY_TAB":
        if (ac.selected>-1)
        {
            if (ac.form[ac.name+"_data"].value != ac.completions[ac.selected].data)
            {
                ac.value = ac.completions[ac.selected].string;
                if (ac.completions[ac.selected].path.length>0)
                {
                    ac.form.action=ac.completions[ac.selected].path;
                }
                ac.form[ac.name+"_data"].value = ac.completions[ac.selected].data;
                ac.completions = [];
                ac.selected = -1;
                comp_node = ac.name+"_list";
                swapDOM(comp_node,DIV({id:comp_node}));
                event.stop ();
            }
        }
        /*else if (ac.name == "cmdline") // in principle this shouldn't be required.
        {
           document.forms[0].submit ();
            event.stop ();
        }*/
        break;
    }
}

function LineSelect(ac)
{
    if (ac.selected > -1)
    {
        setStyle(ac.completions[ac.selected].li,{'background-color':'#eef6ff'});
    }
}

function LineUnselect(ac)
{
    if (ac.selected > -1)
    {
        setStyle(ac.completions[ac.selected].li,{'background-color':'white'});
    }
}