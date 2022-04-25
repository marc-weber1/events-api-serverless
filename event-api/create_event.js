import EventModel from './event.js';


export async function handler(event){
    console.log('Event: ', event);
    
    try{
        const message = JSON.parse(event.body);
        const new_event = new EventModel(message);

        return new_event.save()
            .then(() => {
                return {
                    statusCode: 201,
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({
                        message: "Event created successfully.",
                    }),
                };
            })
            .catch( (err) => {
                console.warn(err);

                return {
                    statusCode: 500,
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({
                        error: err.toString(),
                    }),
                };
            })
    }

    catch(err){
        console.warn(err);

        if( err.name === 'SyntaxError' ){
            return {
                statusCode: 400,
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    error: "Invalid JSON in request body. Is your content-type set to JSON?",
                }),
            };
        }

        else{
            return {
                statusCode: 400,
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    error: err.toString(),
                }),
            };
        }
    }
}