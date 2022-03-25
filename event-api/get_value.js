import knex from 'knex'


const knex_client = knex({
	client: 'mysql',
	connection: {
		host: process.env.db_endpoint,
		port: process.env.db_port,
		user: process.env.db_user,
		password: process.env.db_pass,
		database: process.env.db_name,
	},
});


export async function handler(event){
	console.log('Event: ', event);

    if(event.queryStringParameters && event.queryStringParameters['key']){

        return await knex_client('example').where({key: event.queryStringParameters['key']})
            .then((rows) => {

                if( rows.length == 0 ){
                    return {
                        statusCode: 200,
                        headers: {
                            'Content-Type': 'application/json',
                        },
                        body: JSON.stringify({
                            message: "No matching key found."
                        }),
                    };
                }
                else{
                    return {
                        statusCode: 200,
                        headers: {
                            'Content-Type': 'application/json',
                        },
                        body: JSON.stringify(
                            rows[0]
                        ),
                    };
                }

            })
            .catch((err) => {
                console.warn(err);

                return {
                    statusCode: 500,
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({
                        error: err,
                    }),
                };
            })

    }

    else{
        return {
			statusCode: 400,
			headers: {
				'Content-Type': 'application/json',
			},
			body: JSON.stringify({
				error: "Key is missing from params.",
			})
		};
    }
}