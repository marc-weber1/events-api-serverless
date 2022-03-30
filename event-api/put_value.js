import ExampleModel from './example_model.js';


export async function handler(event){
	console.log('Event: ', event);

	if (event.queryStringParameters && event.queryStringParameters['key'] && event.queryStringParameters['value']) {

		var entry = new ExampleModel({key: event.queryStringParameters['key'], value: event.queryStringParameters['value']});

		return await entry.save()
		.then(() => {
			return {
				statusCode: 201,
				headers: {
					'Content-Type': 'application/json',
				},
				body: JSON.stringify({
					key: entry.get('key'),
					value: entry.get('value')
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
