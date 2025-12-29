package de.init.demo.ai.boundary;

import de.init.demo.ai.control.MyAgent;
import io.smallrye.mutiny.Multi;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

@Path("/hello")
public class MyResource {

    final MyAgent myAgent;

    public MyResource(MyAgent myAgent) {
        this.myAgent = myAgent;
    }

    @POST
    public String hello(String userMessage) {
        return myAgent.chat(userMessage);
    }
}
