(function(host) {

var getTransport = function(){
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
        this.opts = opts;
        this.transport = getTransport();

        this.timeout = setTimeout( createBoundedWrapper( this, function(){
                console.log('timeout');
                this.transport.abort();
                console.log('timeout: init timer');
                var wait = this.opts.wait;
                setTimeout( function(){
                        console.log( 'timeout: check');
                        check( wait ); 
                    }, 1500 );
            } ), this.opts.wait );

        console.log( 'get' );
        this.transport.open( 'get', url, true );
        this.transport.onreadystatechange =
            createBoundedWrapper( this, function(){
                if( this.transport.readyState != 4 ) { return }
                clearTimeout( this.timeout );
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
        wait: wait,
        onSuccess: function(transport) {
            console.log( transport.responseText );

            var json = JSON && JSON.parse(transport.responseText)
                         || eval('('+transport.responseText+')');
            console.log( json );

            if( json.reload || json.changed > start ){
                console.log( 'reload' );
                location.reload(false);        
            } else {
                console.log( 'dont reload' );
                setTimeout( function(){ check(wait) }, 1500 );
            }
        },
        onFailure: function(transport) {
            setTimeout( function(){ check(wait) }, 1500 );
        }
      });

};

// Prevent multiple connections
window['-plackAutoRefresh-'] || (window['-plackAutoRefresh-'] = 1) && check(+"{{wait}}");

})("{{host}}/{{now}}")
