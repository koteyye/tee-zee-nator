export namespace main {
	
	export class Config {
	    api_url: string;
	    api_key: string;
	    last_used_model: string;
	
	    static createFrom(source: any = {}) {
	        return new Config(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.api_url = source["api_url"];
	        this.api_key = source["api_key"];
	        this.last_used_model = source["last_used_model"];
	    }
	}
	export class Model {
	    id: string;
	    object: string;
	    created: number;
	    owned_by: string;
	
	    static createFrom(source: any = {}) {
	        return new Model(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.id = source["id"];
	        this.object = source["object"];
	        this.created = source["created"];
	        this.owned_by = source["owned_by"];
	    }
	}
	export class Template {
	    id: string;
	    name: string;
	    content: string;
	    is_default: boolean;
	
	    static createFrom(source: any = {}) {
	        return new Template(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.id = source["id"];
	        this.name = source["name"];
	        this.content = source["content"];
	        this.is_default = source["is_default"];
	    }
	}

}

