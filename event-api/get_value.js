import ExampleModel from './example_model.js';


export async function handler(event){
	console.log('Event: ', event);

    if(event.queryStringParameters && event.queryStringParameters['key']){

        return await ExampleModel.get(event.queryStringParameters['key'])
            .then((entry) => {

                /*if( rows.length == 0 ){
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
                else{*/
                    return {
                        statusCode: 200,
                        headers: {
                            'Content-Type': 'application/json',
                        },
                        body: JSON.stringify({
                            key: entry.get('key'),
                            value: entry.get('value')
                        }),
                    };
                //}

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