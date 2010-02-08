(function(host) {

var getTransport = function(){
    console.log( "getTransport"); 
    try{ return new XMLHttpRequest()}                   catch(e){};
    try{ return new ActiveXObject('Msxml2.XMLHTTP')}    catch(e){};
    try{ return new ActiveXObject('Microsoft.XMLHTTP')} catch(e){};
    alert("XMLHttpRequest not supported");
};

function createBoundedWrapper( object, method ){
    return function(){
        return method.apply(object,arguments);
    };
}

var Ajax = {
    Request: function(url, opts) {
        this.transport = getTransport();
        this.opts = opts;
        this.transport.open( 'get', url, true );
        this.transport.onreadystatechange =
            createBoundedWrapper( this, function(){
                if( this.transport.readyState != 4 ) { return }
                if( this.transport.status != 200 ){
                    this.opts.onFailure( this.transport );
                } else {
                    this.opts.onSuccess( this.transport );
                }
            } );
        this.transport.send(null);
    }
};


var check =  function(wait){
  var start = +"{{now}}";
  new Ajax.Request( host, {
    onSuccess: function(transport) {
      console.log( transport.responseText );
      var json = JSON && JSON.parse(transport.responseText)
                 || eval('('+transport.responseText+')');
      console.log( json );
      if( json.changed > start ){
         location.reload(false);        
      } else {
        check(wait);
      }
    },
    onFailure: function(transport) {
      check(wait);
    }
  });

};

// Prevent multiple connections
window['-plackAutoRefresh-'] || (window['-plackAutoRefresh-'] = 1) && check(+"{{wait}}");

})("{{host}}")
