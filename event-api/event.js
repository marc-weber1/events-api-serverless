import dynamo from 'dynamodb';
import Joi from 'joi';
dynamo.AWS.config.update({region: process.env.aws_region})

var Event = dynamo.define('Event', {
    hashKey: 'name',
    rangeKey: 'start_time',

    schema: {
        name: Joi.string().required(),
        start_time: Joi.date().required(),

        hosts: dynamo.types.stringSet().min(1).required(),
        description: Joi.string(),
        end_time: Joi.date(),
        location: Joi.object({
            lat: Joi.number().min(-90).max(90).required(),
            long: Joi.number().min(-180).max(180).required()
        }),
        website: Joi.string().uri(),

        tags: dynamo.types.stringSet().default([]),
    }
})
Event.config({tableName: process.env.event_db_name});

export default Event;