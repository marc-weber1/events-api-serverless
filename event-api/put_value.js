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

	if (event.queryStringParameters && event.queryStringParameters['key'] && event.queryStringParameters['value']) {

		return await knex_client('example').insert({
			key: event.queryStringParameters['key'],
			value: event.queryStringParameters['value'],
		}).then(() => {
			return {
				statusCode: 201,
				headers: {
					'Content-Type': 'application/json',
				},
				body: JSON.stringify({
					key: event.queryStringParameters['key'],
					value: event.queryStringParameters['value'],
				}),
			};
		}).catch( (err) => {
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
		});
	}

	else{
	  
		return {
			statusCode: 400,
			headers: {
				'Content-Type': 'application/json',
			},
			body: JSON.stringify({
				error: "Either key or value is missing from params.",
			})
		};
	  
	}
  
};
