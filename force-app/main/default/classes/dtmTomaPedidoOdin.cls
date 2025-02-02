@SuppressWarnings('PMD.AvoidGlobalModifier')
global class dtmTomaPedidoOdin {
    
    global class dtmTomaPedidoOdinResponse {
        global String codigoRespuesta {get;set;}
        global String mensajeRespuesta {get;set;}
        global List<error> errores {get;set;}
        global String folioId {get;set;}
        global String folioGoTelmex {get;set;}
        global Integer statusCode {get;set;}
        global Integer statusCodeAuxiliar {get;set;}
        
        global Map<String, Object> toMap() {
            Map<String, Object> mapa = new Map<String, Object>();
            mapa.put('codigoRespuesta', codigoRespuesta);
            mapa.put('mensajeRespuesta', mensajeRespuesta);
            mapa.put('folioId', folioId);
            mapa.put('folioGoTelmex', folioGoTelmex);
            mapa.put('statusCode', statusCode);
            mapa.put('statusCodeAuxiliar', statusCodeAuxiliar);
            if (errores != null) {
                List<Map<String, Object>> erroresList = new List<Map<String, Object>>();
                for (error e : errores) {
                    erroresList.add(e.toMap());
                }
                mapa.put('errores', erroresList);
            }
            return mapa;
        }
    }
    
    global class error {
        global String error {get;set;}
        
        global Map<String, Object> toMap() {
            Map<String, Object> mapa2 = new Map<String, Object>();
            mapa2.put('error', error);
            return mapa2;
        }
    }
    
    global static dtmTomaPedidoOdinResponse procesarSolicitud(String entradaDatos) {
        String idQuote = entradaDatos;
        String producto = '';
        QuoteLineItem produAgrupador = new QuoteLineItem();
        
        Quote cotizacion = [SELECT Id,Name,Account.Id,Account.dtmRFC__c,Account.dtmCUCE__c,Opportunity.dtmIdentificadorOpp__c,Opportunity.dtmCUP__c FROM Quote WHERE Id=:idQuote];
        System.debug('cotizacion '+cotizacion);
        QuoteLineItem produPadre = [SELECT id,dtmRFC__c,Product2.Id,Product2.ProductCode,Product2.Name,Product2.vlocity_cmt__SpecificationType__c,Product2.dtmLegacyName__c FROM QuoteLineItem WHERE QuoteId=:idQuote AND Product2.vlocity_cmt__SpecificationType__c='Offer'];
        System.debug('produPadre '+produPadre);
        List<QuoteLineItem> productosHijos = [SELECT id,Product2.dtmLegacyName__c,Quantity,Product2.ProductCode, Product2.Name,vlocity_cmt__AttributeSelectedValues__c FROM QuoteLineItem WHERE QuoteId=:idQuote AND Product2.vlocity_cmt__SpecificationType__c='Product' AND Product2.vlocity_cmt__SpecificationSubType__c='Simple'];
        System.debug('productosHijos '+productosHijos);
        
        String jsonRequest = '{';
        //jsonRequest +='"resellerId":"'+cotizacion.Id+'",';//Datos de reseller
        //jsonRequest +='"accountId":"'+cotizacion.Account.Id+'",';//Datos de alta de cuenta en reseller
        jsonRequest +='"resellerId":"1016365",';//Datos de reseller
        jsonRequest +='"accountId":"1016367",';//Datos de alta de cuenta en reseller
        jsonRequest +='"folioGoTelmex":"'+cotizacion.Id+'",';
        jsonRequest +='"codigoPromocion":null,';//Checar con marco
        jsonRequest +='"contratacionCloud":[';
        jsonRequest +='{';
        jsonRequest +='"cveProducto":"'+produPadre.Product2.dtmLegacyName__c+'",';
        switch on produPadre.Product2.Name{
            when 'ASPEL'{
                jsonRequest +='"cvePlan":"ASPEL",';//Va el hijo
            }
            when 'Seguridad Negocio','Respaldo de Información','Tienda en línea'{
                jsonRequest +='"cvePlan":"'+productosHijos[0].Product2.dtmLegacyName__c+'",';
            }
            when 'Correo Negocio'{
                 produAgrupador = [SELECT id,Product2.ProductCode, Product2.Name,Product2.dtmLegacyName__c FROM QuoteLineItem WHERE QuoteId=:idQuote AND Product2.vlocity_cmt__SpecificationType__c='Product' AND Product2.vlocity_cmt__SpecificationSubType__c='Bundle'];
                jsonRequest +='"cvePlan":"'+produAgrupador.Product2.dtmLegacyName__c+'",';
            }
        }
        system.debug('jsonRequest '+jsonRequest);
        
        
        System.debug('jsonRequest '+jsonRequest);
        switch on produPadre.Product2.Name{
            when 'Correo Negocio'{
                if(productosHijos != null){
                    for(QuoteLineItem item :productosHijos){
                        if(item.Product2.ProductCode=='CUENTAS_ADICIONALES'){
                            jsonRequest += '"recursos":[';
                            jsonRequest += '{';
                            jsonRequest += '"nombre": "' + produAgrupador.Product2.dtmLegacyName__c + '",';
                            jsonRequest += '"valor": "' + Integer.valueOf(item.Quantity)+ '"';
                            jsonRequest += '}';
                            jsonRequest += '],';
                        }
                        if(item.Product2.ProductCode=='DOMINIO'){
                            Map<String, Object> parsedValue = (Map<String, Object>) JSON.deserializeUntyped(item.vlocity_cmt__AttributeSelectedValues__c);
                            String primero = (String) parsedValue.get('ATT_DOM_NOMBRE');
                            String segundo = (String) parsedValue.get('ATT_DOM_TIPO');
                            jsonRequest += '"suscripcionAdicional": [';
                            jsonRequest += '{';
                            jsonRequest += '"nombre": "' + item.Product2.ProductCode + '",';
                            jsonRequest += '"valor": "' + primero+segundo + '"';
                            jsonRequest += '}';               
                            jsonRequest += ']';
                        }
                        System.debug('jsonRequest '+jsonRequest);
                    }
                } 
            }
            when 'Respaldo de Información'{
                  jsonRequest += '"recursos": []';
            }
            when 'Seguridad Negocio'{
                if(productosHijos != null){
                    for(QuoteLineItem item :productosHijos){
                        if(item.Product2.Name=='Usuarios Adicionales'){
                            jsonRequest += '"recursos": [';
                            jsonRequest += '{';
                            jsonRequest += '"nombre": "'+ item.Product2.dtmLegacyName__c +'",';
                            jsonRequest += '"valor": "' + Integer.ValueOf(item.Quantity)+ '"';
                            jsonRequest += '}';
                            jsonRequest += ']';
                        }
                    }
                }
            }
            when 'ASPEL'{
                jsonRequest += '"recursos": [';
                for (Integer i = 0; i < productosHijos.size(); i++) {
                    QuoteLineItem item = productosHijos[i];
                    jsonRequest += '{';
                    switch on item.Product2.dtmLegacyName__c{
                        when 'CAJA','SAE','COI','NOI','BANCO','PROD'{
                            Map<String, Object> parsedValue = (Map<String, Object>) JSON.deserializeUntyped(item.vlocity_cmt__AttributeSelectedValues__c);
                            String cantidad = (String) parsedValue.get('ATT_ASPEL_USUARIOS');
                            jsonRequest += '"nombre": "' +item.Product2.dtmLegacyName__c+'",';
                            jsonRequest += '"valor": "' + cantidad + '"';
                        }
                        when 'FACTURE'{
                            Map<String, Object> parsedValue = (Map<String, Object>) JSON.deserializeUntyped(item.vlocity_cmt__AttributeSelectedValues__c);
                            String cantidad = (String) parsedValue.get('ATT_ASPEL_FACTURE_EMPRESAS');
                            if(cantidad=='1'){
                                jsonRequest += '"nombre": "' +item.Product2.dtmLegacyName__c+'",';
                                jsonRequest += '"valor": "1"';
                            }else{
                                jsonRequest += '"nombre": "' +item.Product2.dtmLegacyName__c+'",';
                                jsonRequest += '"valor": "2"';
                            }
                            
                        }
                        when 'NOIASISTENTE'{
                            Map<String, Object> parsedValue = (Map<String, Object>) JSON.deserializeUntyped(item.vlocity_cmt__AttributeSelectedValues__c);
                            String cantidad = (String) parsedValue.get('ATT_ASPEL_NOI_EMPRESAS');
                            String[] plazos = cantidad.split(' ');
                            String paquete = String.valueOf(plazos[1]);
                            jsonRequest += '"nombre": "' +item.Product2.dtmLegacyName__c+'",';
                            jsonRequest += '"valor": "' + paquete + '"';
                        }
                        when 'ADM'{
                            Map<String, Object> parsedValue = (Map<String, Object>) JSON.deserializeUntyped(item.vlocity_cmt__AttributeSelectedValues__c);
                            String tipo = (String) parsedValue.get('ATT_ASPEL_USUARIOS_ADM');
                            jsonRequest += '"nombre": "' +item.Product2.dtmLegacyName__c+'",';
                            if(tipo=='Basica'){
                                jsonRequest += '"valor": "Basico"';
                            }else{
                                jsonRequest += '"valor": "' + tipo + '"';
                            }
                            
                        }
                        when 'ADM_TIMBRES'{
                            Map<String, Object> parsedValue = (Map<String, Object>) JSON.deserializeUntyped(item.vlocity_cmt__AttributeSelectedValues__c);
                            String cantidad = (String) parsedValue.get('ATT_ASPEL_ADM_PAQUETE');
                            String[] plazos = cantidad.split(' ');
                            Integer paquete = Integer.valueOf(plazos[0]);
                            jsonRequest += '"nombre": "' +item.Product2.dtmLegacyName__c+'",';
                            jsonRequest += '"valor": "' + paquete +'CFDI'+'"';
                        }
                        when 'SELLADO'{
                            Map<String, Object> parsedValue = (Map<String, Object>) JSON.deserializeUntyped(item.vlocity_cmt__AttributeSelectedValues__c);
                            String paquetes = (String) parsedValue.get('ATT_ASPEL_TIMBRES');
                            String[] plazos = paquetes.split(' ');
                            Integer paquete = Integer.valueOf(plazos[0]);
                            jsonRequest += '"nombre": "' +item.Product2.dtmLegacyName__c+'_'+paquete+'",';
                            jsonRequest += '"valor": "' + paquete +'CFDI'+ '"';
                        }
                    }
                        jsonRequest += '}';               
                        if (i < productosHijos.size() - 1) {
                            jsonRequest += ',';
                        }
                    }
                jsonRequest += '],';
                System.debug('jsonRequest '+jsonRequest);
                jsonRequest += '"parametros": [';
                jsonRequest += '{';
                jsonRequest += '"nombre": "RFC",';
                jsonRequest += '"valor": "' + produPadre.dtmRFC__c + '"';
                jsonRequest += '}';               
                jsonRequest += ']';
            }
            when 'Tienda en línea'{
                jsonRequest += '"parametros": [],';//Se solicita un correo
                jsonRequest += '"suscripcionAdicional": []';
            }
        }
        jsonRequest +='}';
        jsonRequest +=']';
        jsonRequest +='}';
        
        //String jsonRequest = '{"test":"test"}';
        System.debug('El request a enviar es:'+jsonRequest);
        
        dtmTomaPedidoOdin.dtmTomaPedidoOdinResponse respuesta = new dtmTomaPedidoOdin.dtmTomaPedidoOdinResponse();
        dtmTomaPedidoOdin.dtmTomaPedidoOdinResponse responses = dtmTomaPedidoOdinController.integrarConEndpointExterno(jsonRequest);
        
        if (responses.statusCode==200 && responses.codigoRespuesta=='00') {
            respuesta.statusCode = responses.statusCode;
            respuesta.statusCodeAuxiliar = 200;
            respuesta.mensajeRespuesta = responses.mensajeRespuesta;
            respuesta.codigoRespuesta = responses.codigoRespuesta;
            respuesta.folioId = responses.folioId;
            respuesta.folioGoTelmex = responses.folioGoTelmex;
            cotizacion.dtmFolioOdin__c = responses.folioId;
            update cotizacion;
        } else{
            respuesta.statusCode = responses.statusCode;
            respuesta.statusCodeAuxiliar = 400;
            respuesta.mensajeRespuesta = responses.mensajeRespuesta;
            respuesta.errores = responses.errores;
            respuesta.codigoRespuesta = responses.codigoRespuesta;
            dtmTomaPedidoOdin.guardaErrores(jsonRequest, respuesta, idQuote);
            cotizacion.dtmMensajeError__c = responses.mensajeRespuesta;
            update cotizacion;
        }
        System.debug('Se envia respuesta: '+respuesta);
        return respuesta;
    }
    
    public static void guardaErrores(String jsonEntrada,dtmTomaPedidoOdin.dtmTomaPedidoOdinResponse respuesta,Id idQuote){
        String mensajeError = 'codigoError: '+respuesta.errores +' Mensaje: '+respuesta.mensajeRespuesta;
        Integer codigoEstatus = respuesta.StatusCode;
        vlocity_cmt__VlocityErrorLogEntry__c errorNew = new vlocity_cmt__VlocityErrorLogEntry__c();
        errorNew.vlocity_cmt__Action__c = 'POST';
        errorNew.vlocity_cmt__ErrorCode__c = String.valueOf(codigoEstatus);
        errorNew.vlocity_cmt__ErrorMessage__c = mensajeError;
        errorNew.vlocity_cmt__ErrorTime__c = Datetime.Now();
        errorNew.vlocity_cmt__ErrorType__c = 'Callout Error';
        errorNew.vlocity_cmt__InputData__c = jsonEntrada;
        errorNew.Name = 'Toma Pedido Odin';
        errorNew.vlocity_cmt__ObjectName__c = 'Quote';
        errorNew.vlocity_cmt__SourceType__c = 'Omniscript';
        errorNew.dtmCotizacion__c = idQuote;
        Insert errorNew;
        System.debug('Id de registro: '+errorNew.Id); 
    }
}